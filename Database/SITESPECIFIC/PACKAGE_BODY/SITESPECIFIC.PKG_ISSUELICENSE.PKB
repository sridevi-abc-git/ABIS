CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_ISSUELICENSE"
IS
    -- **************************************************************************
    -- File:        PKG_ISSUELICENSE.PKB
    -- Author:      CX
    --
    -- $Rev: 425 $
    -- $Date: 2020-03-30 14:24:04 -0700 (Mon, 30 Mar 2020) $
    -- Last Changed By:  $Author: PKaur $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- 09/25/2018 NW   WO  2748 - Designated Expiration Date is setting to past
    -- 01/03/2019 TJL  WO 16435 - Added initializing number of months Licensed for
    --                            variable use in testing for seasonals.
    --                            Procedure setexpmonthyear
    -- 02/18/2020 PK   WO 20669 - Added code for original, change and transfer -Issue License.
    -- 03/27/2020 PK   WO 20669 - Added code for Transfer Apps
    -- 08/05/2021 TJL  WO 25899 - Added checking payment method to determine if to use 10 day
    --                              business rule (validatepaymentcheck)
    -- 06/12/2023 NZA  CX 030043 - Added function GetConditionalDoc used in several places
    --                               This replaces the "Max" function call
    -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
    --                              so that it would be copied over to License created t_licleflepid  and  t_applegalentityflepid
    --12/10/2025 PK    6989      Request for New License Type 94 
    -- **************************************************************************

    -- Variable Declarations for package

    t_abc172docid                 udt_id;
    t_appbfofcalternatereldefid   udt_id;
    t_appbfofcdefaultreldefid     udt_id;
    t_appdbanamesreldefid         udt_id;
    t_appdefid                    udt_id;
    t_appexternalfilenum          query.j_application.externalfilenum%TYPE;
    t_applegalentityappepid       udt_id;
    t_applegalentityosmepid       udt_id;
    t_applegalentityflepid        udt_id;
    t_applegalentityp12epid       udt_id;
    t_applegalentityprip12id      udt_id;
    t_applicreldefid              udt_id;
    t_appmailaddrreldefid         udt_id;
    t_applicationtype             query.j_application.applicationtype%TYPE;
    t_apppltepid                  udt_id;
    t_applicableltinvrelid        udt_id;
    t_apppremaddrreldefid         udt_id;
    t_appprilictypereldef         udt_id;
    t_apprelpltsecltc             udt_id;
    t_basefileofcobjid            udt_id;
    t_basefileofc                 query.j_application.displayformat%TYPE;
    t_canltjobprocessobjid        udt_id;
    t_chnglicobjid                udt_id;
    t_createrelendpointid         udt_id;
    t_dbadefid                    udt_id;
    t_dbalicobjid                 udt_id;
    t_dbanameapp                  query.o_dbanames.dba%TYPE;
    t_dbanewobjid                 udt_id;
    t_droppartner                 query.j_application.droppartner%TYPE;
    t_endpointid                  udt_id;
    t_externalfilenum             query.j_application.externalfilenum%TYPE;
    t_felony                      query.j_application.felony%TYPE;
    t_fiduciarytransfer           query.j_application.fiduciarytransfer%TYPE;
    t_fiduciarytype               query.j_application.fiduciarytype%TYPE;
    t_governmentowned             query.j_application.conda%TYPE;
    t_investigationrel            udt_id;
    t_priorityapplication         query.j_application.ispriorityapplication%TYPE;
    t_lastissuelicenseprocess     query.p_issuelicense.isissuealllts%TYPE;
    t_legalentityobjid            udt_id;
    t_licaddrmailreldefid         udt_id;
    t_licaddrpremreldefid         udt_id;
    t_licbasefileofcreldefid      udt_id;
    t_licdbanamesreldefid         udt_id;
    t_licdefid                    udt_id;
    t_licensebeingchanged         query.j_application.licensebeingchanged%TYPE;
    t_licensejobids               api.udt_objectlist;
    t_licensenumber               query.j_application.externalfilenum%TYPE;
    t_licensenumberbeingchanged   query.j_application.licensenumberbeingchanged%TYPE;
    t_licensetransferringfrom     query.j_application.licensetransferringfrom%TYPE;
    t_licensetypeexchange         query.j_application.licensetypeexchange%TYPE;
    t_liclelicenseereldefid       udt_id;
    t_licleosmreldefid            udt_id;
    t_liclep12reldefid            udt_id;
    t_liclictypcatpriobjid        udt_id;
    t_licltepid                   udt_id;
    t_liclelicenseeepid           udt_id;
    t_licleosmepid                udt_id;
    t_licleflepid                 udt_id;
    t_liclep12epid                udt_id;
    t_licleprip12epid             udt_id;
    t_liclictypereldefid          udt_id;
    t_licmailaddrrelid            udt_id;
    t_licobjectid                 udt_id;
    t_licpltobjid                 udt_id;
    t_licrelltsecltc              udt_id;
    t_lictypedefid                udt_id;
    t_lictypejobobjid             udt_id;
    t_lictypltcatprireldefid      udt_id;
    t_lictypltcatpriepid          udt_id;
    t_lictypltcatsecepid          udt_id;
    t_lictypltcatsecreldefid      udt_id;
    t_lictxfrfromobjid            udt_id;
    t_lictxfrfromreldefid         udt_id;
    t_ltcsecobjid                 udt_id;
    t_masterltobjid               udt_id;
    t_mailaddrobjectid            udt_id;
    t_membershiptransfer          query.j_application.membershiptransfer%TYPE;
    t_mstrbranchltepid            udt_id;
    t_mstrbranchpltepid           udt_id;
    t_newobjectid                 udt_id;
    t_newrelobjectid              udt_id;
    t_ofcobjectdefid              udt_id;
    t_objectdefid                 udt_id;
    t_persontoperson              query.j_application.persontoperson%TYPE;
    t_pltobjectlist               api.udt_objectlist;
    t_pltobjidtxfrlic             udt_id;
    t_premaddrobjectid            udt_id;
    t_premisetopremise            query.j_application.premisetopremise%TYPE;
    t_priltltcatprimaryreldef     udt_id;
    t_priltltcatsecondaryreldef   udt_id;
    t_prilictypedefid             udt_id;
    t_readytoissuedate            DATE;
    t_relationshipid              NUMBER;
    t_statusdate                  DATE;
    t_stocktransfer               query.j_application.stocktransfer%TYPE;
    t_tempaddr                    query.j_application.istemporarymailingaddress%TYPE;
    t_violation                   query.j_application.violation%TYPE;
    t_licenseexists               VARCHAR2(1) := 'N';
    t_c1branchapplies             VARCHAR(1);
    t_c1typeofissuance            VARCHAR(4000);
    t_branchlictyperel            udt_id;
    t_licmailaddrobjectid         udt_id;
    t_psltendpointid              udt_id;
    t_pltendpointid               udt_id;
    t_sectypeofissuance           VARCHAR2(40);
    t_emailaddrobjectid           udt_id; -- Added by pawan WO 20669
    t_licemailaddrreldefid        udt_id;
    t_appemailaddrreldefid        udt_id;


    /*********************************************************************************
     * P12ApplicantCount() PUBLIC
     * This function provides the count of P12 relationships for an Application jobid
     *********************************************************************************/
    FUNCTION p12applicantcount(a_objectid NUMBER)
        RETURN NUMBER
    IS
        t_relcount     NUMBER;
        t_p12appepid   NUMBER
            := api.pkg_configquery.endpointidforname('j_Application',
                                                     'P12Applicant');
    BEGIN
        SELECT COUNT(*)
          INTO t_relcount
          FROM api.relationships r
         WHERE r.fromobjectid = a_objectid
           AND r.endpointid = t_p12appepid;

        RETURN t_relcount;
    END p12applicantcount;

    ----------------------------------------------------------------------------------------------------
    --   * GetAppTypeLaunchLic() -- PUBLIC
    -- Using parameter of application objectid
    -- Get the type of application, and call the appropriate issue license procedure
    ----------------------------------------------------------------------------------------------------
    PROCEDURE getapptypelaunchlic(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_jobid         udt_id)
    IS
        t_apptype      VARCHAR(50);
        t_issuetonew   VARCHAR(1);
    BEGIN
        t_apptype   := api.pkg_columnquery.VALUE(a_jobid, 'ApplicationType');
        t_issuetonew   :=
            api.pkg_columnquery.VALUE(a_jobid, 'NewLicenseTransferringTo');
        t_persontoperson   :=
            api.pkg_columnquery.VALUE(a_jobid, 'PersonToPerson');
        t_premisetopremise   :=
            api.pkg_columnquery.VALUE(a_jobid, 'PremiseToPremise');
        t_licensetypeexchange   :=
            api.pkg_columnquery.VALUE(a_jobid, 'LicenseTypeExchange');

        IF t_apptype = 'Original' THEN
            issueoriginallicense(a_jobid, a_objectid);
        ELSIF t_apptype = 'Transfer'
          AND (t_issuetonew = 'Y'
            OR (t_persontoperson = 'N'
            AND t_premisetopremise = 'N'
            AND t_licensetypeexchange = 'N')) THEN
            issuetransferlicense(a_jobid, a_objectid);
        ELSIF t_apptype = 'Transfer'
          AND t_issuetonew = 'N' THEN
            issuetransfertoactivelicense(a_jobid, a_objectid);
        ELSIF t_apptype = 'Change' THEN
            issuechangelicense(a_jobid, a_objectid);
        END IF;
    END getapptypelaunchlic;

    ----------------------------------------------------------------------------------------------------
    --   * GetEndPointId() -- PUBLIC
    -- Get the ToEndPointId for a given relationsihpdef.
    -- Returns t_ToEndPointId, which can be used for creating a new relationship between objects.
    ----------------------------------------------------------------------------------------------------
    FUNCTION gettoendpointid(a_relationshipdefid udt_id,
                             a_objectdefid   udt_id)
        RETURN udt_id
    IS
        t_toendpointid   udt_id;
    BEGIN
        SELECT toendpointid
          INTO t_toendpointid
          FROM api.relationshipdefs
         WHERE relationshipdefid = a_relationshipdefid
           AND toobjectdefid = a_objectdefid;

        RETURN t_toendpointid;
    END gettoendpointid;

    ----------------------------------------------------------------------------------------------------
    --   * SetExpMonthYear()
    -- Using parameter of application objectid(????)
    -- Set the ExpirationMonth and ExpirationYear using Primary License Type object data if exists.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE setexpmonthyear(a_objectid      udt_id,
                              a_asofdate      DATE,
                              a_prilictypeid  udt_id,
                              a_jobid         udt_id)
    IS
        t_expmonnum                  query.j_licensetype.expiringmonthnumber%TYPE;
        t_expmon                     query.j_licensetype.expiringmonth%TYPE;
        t_expyear                    query.j_licensetype.expiringyear%TYPE;
        t_nummonslic                 query.o_primarylicensetype.numberofmonthslicensednumber%TYPE;
        t_readytoissuedate           DATE;
        t_addrenewalfee              VARCHAR2(1);
        t_designatedexpirationdate   VARCHAR2(1);
        t_pairedmasterlt             VARCHAR2(100);
        t_process                    VARCHAR2(1) := 'Y';
        t_istransferred              BOOLEAN;
        t_transferredfromltjobid     udt_id
            := NVL(
                   api.pkg_columnquery.VALUE(a_prilictypeid,
                                             'TransFromLTObjectId'),
                   api.pkg_columnquery.VALUE(a_prilictypeid,
                                             'ChangeLTObjectId'));
        t_expirationdate             DATE;
        t_licensetypecode            VARCHAR(3);
    BEGIN
        t_readytoissuedate   :=
            api.pkg_columnquery.datevalue(a_objectid, 'ReadyToIssueDate');
        t_addrenewalfee   :=
            api.pkg_columnquery.VALUE(a_prilictypeid, 'AddRenewalFee');
        t_designatedexpirationdate   :=
            api.pkg_columnquery.VALUE(a_prilictypeid,
                                      'DesignatedExpirationDate');
        t_pairedmasterlt   :=
            api.pkg_columnquery.VALUE(a_prilictypeid, 'PairedMasterLT');
        t_licensetypecode   :=
            api.pkg_columnquery.VALUE(a_prilictypeid, 'LicenseTypeCode');

        IF api.pkg_columnquery.VALUE(a_prilictypeid, 'IsTransferred') = 'Y'
       AND api.pkg_columnquery.VALUE(a_objectid, 'PersonToPerson') = 'N' THEN
            t_istransferred   := TRUE;
        END IF;

        -- 01/03/2019 TJL  16435 Added initializing number of months Licensed
        t_nummonslic   :=
            api.pkg_columnquery.VALUE(a_prilictypeid,
                                      'NumberOfMonthsLicensedNumber');

        --Checking to see if we are issuing an 02 License Type, this will set the epiration date to the next June 30th in the timeline
        IF t_licensetypecode IN ('02',
                                 '22',
                                 '26',
                                 '28') THEN
            SELECT CASE
                       WHEN TO_CHAR(SYSDATE, 'MM') <= '06' THEN
                           TO_CHAR(SYSDATE, 'YYYY')
                       ELSE
                           TO_CHAR(ADD_MONTHS(SYSDATE, 12), 'YYYY')
                   END
              INTO t_expyear
              FROM DUAL;

            api.pkg_columnupdate.setvalue(a_jobid, 'ExpiringMonth', 'JUNE');
            api.pkg_columnupdate.setvalue(a_jobid, 'ExpiringYear', t_expyear);
        --Checking to see if we are issuing an 67,80 License Type, this will set the epiration date to the next June 30th in the timeline
        ELSIF t_licensetypecode IN ('67', '80', '94') THEN ----12/10/2025 PK    6989      Request for New License Type 94 
            SELECT CASE
                       WHEN TO_CHAR(SYSDATE, 'MM') <= '12' THEN
                           TO_CHAR(SYSDATE, 'YYYY')
                       ELSE
                           TO_CHAR(ADD_MONTHS(SYSDATE, 12), 'YYYY')
                   END
              INTO t_expyear
              FROM DUAL;

            api.pkg_columnupdate.setvalue(a_jobid,
                                          'ExpiringMonth',
                                          'DECEMBER');
            api.pkg_columnupdate.setvalue(a_jobid, 'ExpiringYear', t_expyear);
        ELSE
            IF t_pairedmasterlt IS NOT NULL THEN
                BEGIN
                    --get the latest expirationdate
                    SELECT MAX(lt.expirationdate)
                      INTO t_expirationdate
                      FROM query.r_licenselicensetype  llt
                           JOIN query.j_license l
                               ON l.jobid = llt.licensejobid
                           JOIN query.r_licenselicensetype llt2
                               ON llt2.licensejobid = l.jobid
                           JOIN query.j_licensetype lt
                               ON lt.jobid = llt2.licensetypejobid
                     WHERE llt.licensetypejobid = a_jobid
                       AND lt.jobid <> a_jobid
                       AND t_pairedmasterlt LIKE
                               '%' || lt.licensetypecode || '%';

                    SELECT TO_CHAR(t_expirationdate, 'YYYY'),
                           TRIM(UPPER(TO_CHAR(t_expirationdate, 'Month')))
                      INTO t_expyear, t_expmon
                      FROM DUAL;

                    api.pkg_columnupdate.setvalue(a_jobid,
                                                  'ExpiringYear',
                                                  t_expyear);
                    api.pkg_columnupdate.setvalue(a_jobid,
                                                  'ExpiringMonth',
                                                  t_expmon);
                    t_process   := 'N';
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_process   := 'Y';
                END;
            ELSIF t_process = 'Y' THEN
                -- Set Expiring month (assume that all Seasonal Primary License Types ExpiringMonth detail will be set)
                t_expmonnum   :=
                    api.pkg_columnquery.VALUE(a_prilictypeid,
                                              'ExpiringMonthNumber');

                IF t_expmonnum IS NOT NULL THEN
                    -- Expiring month exists on PLT use it.
                    api.pkg_columnupdate.setvalue(
                        a_jobid,
                        'ExpiringMonth',
                        api.pkg_columnquery.VALUE(a_prilictypeid,
                                                  'ExpiringMonth'));
                ELSE
                    IF t_istransferred THEN
                        t_expmon   :=
                            api.pkg_columnquery.VALUE(
                                t_transferredfromltjobid,
                                'ExpiringMonth');
                    ELSE
                        -- Set the ExpiringMonth to the previous month from the current month)
                        CASE TO_NUMBER(TO_CHAR(t_readytoissuedate, 'MM'))
                            WHEN 1 THEN
                                t_expmon   := 'DECEMBER';
                            WHEN 2 THEN
                                t_expmon   := 'JANUARY';
                            WHEN 3 THEN
                                t_expmon   := 'FEBRUARY';
                            WHEN 4 THEN
                                t_expmon   := 'MARCH';
                            WHEN 5 THEN
                                t_expmon   := 'APRIL';
                            WHEN 6 THEN
                                t_expmon   := 'MAY';
                            WHEN 7 THEN
                                t_expmon   := 'JUNE';
                            WHEN 8 THEN
                                t_expmon   := 'JULY';
                            WHEN 9 THEN
                                t_expmon   := 'AUGUST';
                            WHEN 10 THEN
                                t_expmon   := 'SEPTEMBER';
                            WHEN 11 THEN
                                t_expmon   := 'OCTOBER';
                            WHEN 12 THEN
                                t_expmon   := 'NOVEMBER';
                            ELSE
                                NULL;
                        END CASE;
                    END IF;

                    api.pkg_columnupdate.setvalue(a_jobid,
                                                  'ExpiringMonth',
                                                  t_expmon);
                END IF;

                --If t_DesignatedExpirationDate in 'Y' then set the expiration Year to the current Year, else proceed as normal
                IF t_designatedexpirationdate = 'Y'
               AND t_addrenewalfee = 'Y' THEN
                    t_expyear   :=
                        TO_NUMBER(TO_CHAR(t_readytoissuedate, 'YYYY') + 1);
                ELSIF t_designatedexpirationdate = 'Y' THEN
                    -- Set Expiring year
                    --                t_expyear := TO_NUMBER(TO_CHAR(t_readytoissuedate, 'YYYY'));  -- NW: WO 2748

                    -- Set expiration year to current year if expiration month is not past
                    IF t_expmonnum >=
                       TO_NUMBER(TO_CHAR(t_readytoissuedate, 'MM')) THEN
                        t_expyear   :=
                            TO_NUMBER(TO_CHAR(t_readytoissuedate, 'YYYY'));
                    -- else set expiration year to next year
                    ELSE
                        t_expyear   :=
                            TO_NUMBER(
                                TO_CHAR(t_readytoissuedate, 'YYYY') + 1);
                    END IF;

                    t_nummonslic   :=
                        api.pkg_columnquery.VALUE(
                            a_prilictypeid,
                            'NumberOfMonthsLicensedNumber');
                ELSIF t_nummonslic > 0 THEN
                    -- set year for seasonal license (assume that the only time the NumberOfMonthsLicensed is >0 is on seasonal)
                    -- where month is the same or later than the ReadyToIssueDate monthand AddRenewalFee on the
                    -- PrimaryLicenseType object is N
                    IF t_expmonnum >=
                       TO_NUMBER(TO_CHAR(t_readytoissuedate, 'MM'))
                   AND t_addrenewalfee = 'N' THEN
                        -- The expiration year is the current year
                        t_expyear   :=
                            TO_NUMBER(TO_CHAR(t_readytoissuedate, 'YYYY'));
                    -- set year for seasonal license where month is the same or later than the ReadyToIssueDate month and
                    -- AddRenewalFee on the PrimaryLicenseType object is Y
                    ELSIF t_expmonnum >=
                          TO_NUMBER(TO_CHAR(t_readytoissuedate, 'MM'))
                      AND t_addrenewalfee = 'Y' THEN
                        -- The expiration year is the current year + 1
                        t_expyear   :=
                            TO_NUMBER(
                                TO_CHAR(t_readytoissuedate, 'YYYY') + 1);
                    -- set year for seasonal license where month is earlier than the ReadyToIssueDate month and AddRenewalFee is Y
                    ELSIF (t_expmonnum <
                           TO_NUMBER(TO_CHAR(t_readytoissuedate, 'MM'))
                        OR t_expmonnum IS NULL)
                      AND t_addrenewalfee = 'Y' THEN
                        -- The expiration year is the current year + 2
                        t_expyear   :=
                            TO_NUMBER(
                                TO_CHAR(t_readytoissuedate, 'YYYY') + 2);
                    -- set year for seasonal license where month is earlier than the ReadyToIssueDate month and AddRenewalFee is N
                    ELSE
                        -- the expiration year is the current year + 1
                        t_expyear   :=
                            TO_NUMBER(
                                TO_CHAR(t_readytoissuedate, 'YYYY') + 1);
                    END IF;
                ELSE
                    -- set year for annual license
                    IF t_istransferred THEN
                        t_expyear   :=
                            api.pkg_columnquery.VALUE(
                                t_transferredfromltjobid,
                                'ExpiringYear');
                    ELSE
                        -- Set year to current year when month is December and AddRenewalFee = N
                        IF t_expmon = 'DECEMBER'
                       AND t_addrenewalfee = 'N' THEN
                            t_expyear   :=
                                TO_NUMBER(
                                    TO_CHAR(t_readytoissuedate, 'YYYY'));
                        -- Set year to next year when month is December and AddRenewalFee = Y
                        ELSIF t_expmon = 'DECEMBER'
                          AND t_addrenewalfee = 'Y' THEN
                            t_expyear   :=
                                TO_NUMBER(
                                    TO_CHAR(t_readytoissuedate, 'YYYY') + 1);
                        -- Else set year to year after next if AddRenewaFee = Y
                        ELSIF t_addrenewalfee = 'Y' THEN
                            t_expyear   :=
                                TO_NUMBER(
                                    TO_CHAR(t_readytoissuedate, 'YYYY') + 2);
                        -- Else set year to next year if AddRenewaFee = N
                        ELSE
                            t_expyear   :=
                                TO_NUMBER(
                                    TO_CHAR(t_readytoissuedate, 'YYYY') + 1);
                        END IF;
                    END IF;
                END IF;

                api.pkg_columnupdate.setvalue(a_jobid,
                                              'ExpiringYear',
                                              t_expyear);
            END IF;
        END IF;
    END setexpmonthyear;
  ----------------------------------------------------------------------------------------------------
    --   * GetConditionalDoc() -- PUBLIC
    -- Get the Object ID for the latest ABC 172 document.
    -- Returns t_abc172docid, which can be used to access the related document.
    ----------------------------------------------------------------------------------------------------
    FUNCTION GetConditionalDoc(a_appobjectid udt_id)
        RETURN udt_id
    IS
        t_abc172docid   udt_id;
        t_EPId          udt_Id;
    BEGIN
        t_EPId := api.pkg_configquery.endpointidforname(
                   'j_Application',
                   'ABCWordDocument');

        SELECT c.toobjectid
          INTO t_abc172docid
          FROM api.relationships  c
               JOIN query.d_abcworddocument d
                   ON d.objectid = c.toobjectid
         WHERE c.fromobjectid = a_appobjectid
           AND c.endpointid = t_EPId
           AND d.wordreporttype like 'ABC-172%'
         ORDER BY c.logicaltransactionid DESC
         fetch first 1 rows only;

        return t_abc172docid;

    EXCEPTION WHEN NO_DATA_FOUND THEN
        return NULL;
    END GetConditionalDoc;

    ----------------------------------------------------------------------------------------------------
    --  IssueOriginalLicense() -- PUBLIC
    -- Create a license job, based on parameter from the application job
    -- Copy the application job details and relationships which are needed onto the license job
    -- Create a License Type job for each Primary License Type on the Application
    -- Relate each License Type job to License Type Category (Primary and Secondary)
    -- Move all related Investigation jobs from the Application to the new License job.
    -- Relate License to Prem Address, Mail Address, Base File Office
    -- Copy ExternalFileNum of App to Lic; numeric will be used as the LicenseNumber on the license job.
    -- TODO Relate License to Conditions Document
    ----------------------------------------------------------------------------------------------------
    PROCEDURE issueoriginallicense(a_appobjectid   udt_id,
                                   a_processobjid  udt_id DEFAULT NULL)
    IS
    BEGIN
        t_appdefid   :=
            api.pkg_configquery.objectdefidforname('j_Application');
        t_apppltepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'PrimaryLicenseType');
        t_dbadefid   := api.pkg_configquery.objectdefidforname('o_DBANames');
        t_appdbanamesreldefid   :=
            api.pkg_configquery.objectdefidforname('r_ApplicationDBANames');
        t_licdbanamesreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseDBANames');
        t_applegalentityappepid :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Applicant');
        t_applegalentityosmepid :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'OnSaleManager');
        t_applegalentityflepid  :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'FoodLesseeApp');   -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
        t_applegalentityp12epid :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'P12Applicant');
        t_applegalentityprip12id :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'PrimaryP12Applicant');
        t_liclelicenseeepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'LicenseeLegalEntity');
        t_licleosmepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'OSMLegalEntity');
        t_licleflepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'FoodLesseeLic');    -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
        t_liclep12epid   :=
            api.pkg_configquery.endpointidforname('j_License', 'P12Licensee');
        t_licleprip12epid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'PrimaryP12Licensee');
        t_licltepid   :=
            api.pkg_configquery.endpointidforname('j_License', 'LicenseType');
        t_mstrbranchltepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'MasterLicenseType');
        t_mstrbranchpltepid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'MasterLicenseType');
        t_prilictypedefid   :=
            api.pkg_configquery.objectdefidforname('o_PrimaryLicenseType');
        t_licdefid   :=
            api.pkg_configquery.objectdefidforname('j_License');
        t_lictypedefid   :=
            api.pkg_configquery.objectdefidforname('j_LicenseType');
        t_priltltcatprimaryreldef   :=
            api.pkg_configquery.objectdefidforname('r_PriLTLTCatPrimary');
        t_priltltcatsecondaryreldef   :=
            api.pkg_configquery.objectdefidforname('r_PriLTLTCatSecondary');
        t_appprilictypereldef   :=
            api.pkg_configquery.objectdefidforname('r_AppPrimaryLicenseType');
        t_applicreldefid   :=
            api.pkg_configquery.objectdefidforname('r_ApplicationLicense');
        t_apppremaddrreldefid   :=
            api.pkg_configquery.objectdefidforname('r_ApplicationPremAddr');
        t_appmailaddrreldefid   :=
            api.pkg_configquery.objectdefidforname('r_ApplicationMailAddr');
        t_appbfofcalternatereldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_AppBaseFileAlternateOfc');
        t_appbfofcdefaultreldefid   :=
            api.pkg_configquery.objectdefidforname('r_AppBaseFileDefaultOfc');
        t_lastissuelicenseprocess   :=
            api.pkg_columnquery.VALUE(a_processobjid, 'IsIssueAllLTs');
        t_licbasefileofcreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicBaseFileOffice');
        t_licaddrpremreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseAddrPremises');
        t_licaddrmailreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseAddrMailing');
        t_liclelicenseereldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseLegalEntityLicensee');
        t_licleosmreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseLegalEntityOSM');
        t_liclep12reldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseP12LegalEntity');
        t_lictypltcatprireldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseTypeLTCatPrimary');
        t_lictypltcatsecreldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseTypeLTCatSecondary');
        t_lictypltcatpriepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'LicTypeCatPrimary');
        t_lictypltcatsecepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'LicTypeCatSecondary');
        t_ofcobjectdefid   :=
            api.pkg_configquery.objectdefidforname('o_Office');
        t_psltendpointid   :=
            api.pkg_configquery.endpointidforname(
                'o_PendingSecondaryLicenseType',
                'PendLicTypeCatSecondary');
        t_pltendpointid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'PendSecLicType');
        t_appemailaddrreldefid  :=
            api.pkg_configquery.objectdefidforname('r_EmailsApplication'); -- WO 20669 Added by Pawan on 2/18/2020 for Price posting email
        t_licemailaddrreldefid  :=
            api.pkg_configquery.objectdefidforname('r_EmailsLicense'); -- WO 20669 Added by Pawan on 2/18/2020 for Price posting email


        BEGIN
            SELECT al.licensejobid, 'Y'
              INTO t_licobjectid, t_licenseexists
              FROM query.r_applicationlicense al
             WHERE al.applicationjobid = a_appobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- ### create new License object and relate the application
                t_licenseexists   := 'N';
                t_licobjectid     := api.pkg_objectupdate.new(t_licdefid);
                t_endpointid      :=
                    gettoendpointid(t_applicreldefid, t_appdefid);
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_licobjectid,
                                                   a_appobjectid);

                -- Copy stored dynamic details from existing Application job to
                -- the details of the new License job
                pkg_copy.copystoredobjdetailsexception(
                    a_appobjectid,
                    t_licobjectid,
                    'StatusDate,IsGeocoded');
        END;

        -- All IssueLicense processes run after the first one
        -- will only copy license types to the existing license.
        IF t_licenseexists = 'N' THEN
            -- Copy ExternalFileNum from Application to License
            SELECT externalfilenum
              INTO t_appexternalfilenum
              FROM query.j_application
             WHERE objectid = a_appobjectid;

            -- Copy ExternalFileNum of Application to ExternalFileNum of License
            t_licensenumber   := (SUBSTR(t_appexternalfilenum, 1, 6));
            api.pkg_jobupdate.setexternalfilenum(t_licobjectid,
                                                 t_licensenumber);

            -- 03.04.2008 recoded dba section, as there is now only one rel to app, and one to lic. Loren
            BEGIN                                -- dba from app copied to lic
                FOR c IN (SELECT c.fromobjectid dbaappobjid
                            FROM api.relationships c
                           WHERE c.relationshipdefid = t_appdbanamesreldefid
                             AND c.toobjectid = a_appobjectid)
                LOOP
                    -- find the endpointid for the relationship to license
                    t_endpointid    :=
                        gettoendpointid(t_licdbanamesreldefid, t_licdefid);

                    -- create a DBA object to associate with the license
                    t_dbanewobjid   := api.pkg_objectupdate.new(t_dbadefid);

                    -- Copy stored dynamic details from existing DBA Object to the
                    -- the details of the new DBA object
                    pkg_copy.copystoredobjectdetails(c.dbaappobjid,
                                                     t_dbanewobjid);

                    -- relate the Primary DBA to the license
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_endpointid,
                                                       t_dbanewobjid,
                                                       t_licobjectid);
                END LOOP;                                                --dba
            EXCEPTION
                WHEN NO_DATA_FOUND THEN         -- api.pkg_Errors.RaiseError()
                    t_newrelobjectid   := NULL; -- TODO Should this be handled some other way?
            END;                                 -- dba from app copied to lic

            BEGIN
                -- relate Office to License.find the Office Code on the application
                SELECT basefileofficeid
                  INTO t_basefileofcobjid
                  FROM query.j_application
                 WHERE objectid = a_appobjectid;

                -- relate the office to the license
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_License',
                            'LicenseToOffice'),
                        t_licobjectid,
                        t_basefileofcobjid);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'ERROR. Base File Office could not be determined.'
                        || SQLERRM);
            END;

            BEGIN
                -- ### relate the Premise Address to the license
                SELECT c.fromobjectid
                  INTO t_premaddrobjectid
                  FROM api.relationships c
                 WHERE c.relationshipdefid = t_apppremaddrreldefid
                   AND c.toobjectid = a_appobjectid;

                -- find the endpointid for the lic/prem relationship
                t_endpointid   :=
                    gettoendpointid(t_licaddrpremreldefid, t_licdefid);

                -- relate the prem address to the license
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_premaddrobjectid,
                                                   t_licobjectid);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_newrelobjectid   := NULL;
            END;

            BEGIN -- relate the Mailing Address to the license, if it is not temporary
                SELECT r.toobjectid, a.istemporarymailingaddress
                  INTO t_mailaddrobjectid, t_tempaddr
                  FROM query.j_application  a
                       JOIN api.relationships r ON r.fromobjectid = a.jobid
                 WHERE a.jobid = a_appobjectid
                   AND r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_Application',
                           'MailingAddress');

                -- if not a temporary address and this is not a P12 application then create the Mailing Address Rel
                IF t_tempaddr <> 'Y'
               AND p12applicantcount(a_appobjectid) = 0 THEN
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'MailingAddress'),
                            t_licobjectid,
                            t_mailaddrobjectid);
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_newrelobjectid   := NULL;
            END;

            BEGIN
              -- ### relate the Email Address to the license     WO 20669 Added by Pawan on 2/18/2020 for Price Posting email
                 SELECT c.fromobjectid
                  INTO t_emailaddrobjectid
                  FROM api.relationships c
                 WHERE c.relationshipdefid = t_appemailaddrreldefid
                   AND c.toobjectid = a_appobjectid;

                -- find the endpointid for the lic/email relationship
                t_endpointid   :=
                    gettoendpointid(t_licemailaddrreldefid, t_licdefid);

                -- relate the email address to the license
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_emailaddrobjectid,
                                                   t_licobjectid);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_newrelobjectid   := NULL;
            END; --Ended WO 20669 Added by Pawan on 2/18/2020 for Price Posting email

            -- Find the current revision of the Conditions Document ABC-172 (if exists), and relate to License
            BEGIN
                t_abc172docid := GetConditionalDoc(a_appobjectid);
                IF t_abc172docid IS NOT NULL THEN
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'ABCWordDocument'),
                            t_licobjectid,
                            t_abc172docid);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'ERROR with Conditions Doc. ' || SQLERRM);
            END;
        END IF;                                        -- t_LicenseExists skip

        -- ### Create one License Type Job for each Primary License Type found on the Application.
        -- Copy stored details on Primary License Type to License Type Job.
        -- Set batch flag "IncludeInBatch".
        -- Relate to the License Job to each License Type Job.
        -- Find the relationships between each Primary License Type and
        --  1. License Type Category for Primary License Type
        --  2. License Type Category for Secondary License Type

        --Get the Application's Ready to issue Date
        t_readytoissuedate   :=
            api.pkg_columnquery.datevalue(a_appobjectid, 'ReadyToIssueDate');

        -- Grab all the Primary License Types associated with the Application
        /*select api.udt_object(ilt.PrimaryLicenseTypeObjectId)
          bulk collect into t_PLTObjectList
          from query.r_IssueLicensePLT ILT
         where ilt.IssueLicenseProcessId = a_ProcessObjId
           and (ilt.issue = 'Y'
           or api.pkg_columnquery.value(ilt.IssueLicenseProcessId, 'IssueAllLicenseTypes') = 'Y');*/
        SELECT api.udt_object(r.licensetypeobjectid) prilictypeobjid
          BULK COLLECT INTO t_pltobjectlist
          FROM query.r_appprimarylicensetype  r
               JOIN query.r_issuelicenseplt ilt
                   ON ilt.primarylicensetypeobjectid = r.licensetypeobjectid
         WHERE r.applicationobjectid = a_appobjectid               --1151959--
           AND ilt.issuelicenseprocessid = a_processobjid          --1151986--
           AND api.pkg_columnquery.VALUE(r.licensetypeobjectid, 'Issued') =
               'N'
           AND (ilt.issue = 'Y'
             OR api.pkg_columnquery.VALUE(ilt.issuelicenseprocessid,
                                          'IssueAllLicenseTypes') =
                'Y')
           AND api.pkg_columnquery.VALUE(r.licensetypeobjectid, 'Status') NOT IN
                   (SELECT UPPER(s.description)
                      FROM api.statuses  s
                           JOIN api.jobstatuses js
                               ON js.statusid = s.statusid
                              AND js.jobtypeid =
                                  api.pkg_configquery.objectdefidforname(
                                      'j_LicenseType')
                     WHERE js.statustype IN ('C', 'X'));

        FOR c_1 IN 1 .. t_pltobjectlist.COUNT
        LOOP
            /*(select
                        r.LicenseTypeObjectId PriLicTypeObjId,
                        api.pkg_columnquery.value(r.LicenseTypeObjectId, 'StatusDate') StatusDate,
                        api.pkg_columnquery.value(r.LicenseTypeObjectId, 'LicenseTypeCode') LicenseTypeCode,
                        api.pkg_columnquery.value(r.LicenseTypeObjectId, 'BranchApplies') BranchApplies,
                        api.pkg_columnquery.value(r.LicenseTypeObjectId, 'TypeOfIssuance') TypeOfIssuance
                        from query.r_appprimarylicensetype r
                        where r.ApplicationObjectId = a_AppObjectId
                          and api.pkg_columnquery.value(r.LicenseTypeObjectId, 'Issued') = 'N'
                          and r.LicenseTypeObjectId in (select * from table(cast(t_PLTObjectList as api.Udt_Objectlist)) t )
                          and api.pkg_columnquery.value(r.LicenseTypeObjectId, 'Status') not in
                                     (select upper(s.Description)
                                        from api.statuses s
                                        join api.jobstatuses js
                                          on js.StatusId = s.StatusId
                                          and js.JobTypeId = api.pkg_configquery.ObjectDefIdForName('j_LicenseType')
                                       where js.StatusType in ('C', 'X'))
                        )loop*/
            --t_AppPriLicTypeRelDef
            SELECT /*api.pkg_columnquery.value(r.LicenseTypeObjectId, 'StatusDate') StatusDate,
                   api.pkg_columnquery.value(r.LicenseTypeObjectId, 'LicenseTypeCode') LicenseTypeCode,*/
                   api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                             'BranchApplies')
                       branchapplies,
                   api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                             'TypeOfIssuance')
                       typeofissuance
              INTO /*t_c1StatusDate,
                   t_c1LicenseTypeCode,*/
                   t_c1branchapplies, t_c1typeofissuance
              FROM query.r_appprimarylicensetype r
             WHERE r.licensetypeobjectid = t_pltobjectlist(c_1).objectid;

            -- Create (or find) new License Type Object
            BEGIN
                SELECT jobid
                  INTO t_lictypejobobjid
                  FROM api.jobs
                 WHERE externalfilenum =
                          api.pkg_columnquery.VALUE(
                              t_pltobjectlist(c_1).objectid,
                              'LicenseTypeCode')
                       || '-'
                       || api.pkg_columnquery.VALUE(t_licobjectid,
                                                    'ExternalFileNum')
                   AND jobtypeid = t_lictypedefid;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_lictypejobobjid   :=
                        api.pkg_objectupdate.new(t_lictypedefid);

                    -- Relate the License Type Job to License
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'LicenseType'),
                            t_licobjectid,
                            t_lictypejobobjid);
            END;

            -- Set the Issued Boolean when the PLT is included in the Issue process.
            api.pkg_columnupdate.setvalue(t_pltobjectlist(c_1).objectid,
                                          'Issued',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_pltobjectlist(c_1).objectid,
                                          'Status',
                                          'ISSUED');

            -- Copy stored details from Primary License Type object to License Type Job
            pkg_copy.copystoredobjectdetails(t_pltobjectlist(c_1).objectid,
                                             t_lictypejobobjid);

            -- Copy the Ready To Issue Date to the Licnese Type
            api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                          'ReadyToIssueDate',
                                          t_readytoissuedate);

            -- Copy the Type of Issuance to the License Type
            api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                          'TypeofIssuance',
                                          t_c1typeofissuance);

            -- Set Expiring Month and Year
            pkg_issuelicense.setexpmonthyear(a_appobjectid,
                                             SYSDATE,
                                             t_pltobjectlist(c_1).objectid,
                                             t_lictypejobobjid);

            -- Set the batch flags
            pkg_batchtype.setbatchflags(
                a_lictypejobid => t_lictypejobobjid,
                a_includeinproducelicensebatch => 'Y',
                a_includeindailybatch => 'Y');

            -- Master/Branch License Type Candidate
            IF t_c1branchapplies = 'Y' THEN
                FOR b_1
                    IN (SELECT toobjectid masterltobjid, relationshipid
                          FROM api.relationships
                         WHERE fromobjectid = t_pltobjectlist(c_1).objectid
                           AND endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_PrimaryLicenseType',
                                   'MasterLicenseType'))
                LOOP
                    -- Remove rel from PLT to LT
                    api.pkg_relationshipupdate.remove(b_1.relationshipid);
                    api.pkg_columnupdate.setvalue(
                        t_pltobjectlist(c_1).objectid,
                        'IsBranchS',
                        'Y');

                    -- Relate the Branch to the Master
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_LicenseType',
                                'MasterLicenseType')      --t_MstrBranchLTEPId
                                                    ,
                            t_lictypejobobjid,
                            b_1.masterltobjid);

                    --Set the ExpirationDate of the new Branch LT to the ExpirationDate of it's Master LT
                    api.pkg_columnupdate.setvalue(
                        t_lictypejobobjid,
                        'ExpiringMonth',
                        api.pkg_columnquery.VALUE(b_1.masterltobjid,
                                                  'ExpiringMonth'));
                    api.pkg_columnupdate.setvalue(
                        t_lictypejobobjid,
                        'ExpiringYear',
                        api.pkg_columnquery.VALUE(b_1.masterltobjid,
                                                  'ExpiringYear'));
                END LOOP;

                --get the relationship of when the issuing PLT is related to a Master PLT  Copy it over and remove the previous rel from the original Branch PLT to the Master PLT
                FOR b_2
                    IN (SELECT r.toobjectid     masterplt,
                               r.relationshipid tomasterrelid
                          FROM api.relationships r
                         WHERE r.fromobjectid = t_pltobjectlist(c_1).objectid
                           AND r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_PrimaryLicenseType',
                                   'BranchtoMaster'))
                LOOP
                    --Create the new relationship from the Branch j_LicenseType to the Master PLT
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_LicenseType',
                                'MasterBranchLicenseType'),
                            t_lictypejobobjid,
                            b_2.masterplt);
                    --remove the relationship from the previous Branch PLT to the Master PLT
                    api.pkg_relationshipupdate.remove(b_2.tomasterrelid);
                    api.pkg_columnupdate.setvalue(
                        t_pltobjectlist(c_1).objectid,
                        'IsBranchS',
                        'Y');
                END LOOP;                     --to Master Primary License Type

                --get the relationship of when the issuing PLT is related to a Branch PLT
                --Copy it over and remove the previous rel from the original Master PLT to the Branch PLT
                FOR b_3
                    IN (SELECT r.toobjectid branchplt, r.relationshipid
                          FROM api.relationships r
                         WHERE r.fromobjectid = t_pltobjectlist(c_1).objectid
                           AND r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_PrimaryLicenseType',
                                   'MastertoBranch'))
                LOOP
                    --Create the new relationship from the Master j_LicenseType to the Branch PLT
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_LicenseType',
                                'BranchPrimaryLicenseType'),
                            t_lictypejobobjid,
                            b_3.branchplt);
                    --remove the relationship from the previous Branch PLT to the Master PLT
                    api.pkg_relationshipupdate.remove(b_3.relationshipid);
                END LOOP;                     --to Master Primary License Type

                ------+++++ PLT is a Master of a Branch License Type
                FOR b_4
                    IN (SELECT toobjectid masterltobjid, relationshipid
                          FROM api.relationships
                         WHERE fromobjectid = t_pltobjectlist(c_1).objectid
                           AND endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_PrimaryLicenseType',
                                   'MasterPrimaryLicenseType'))
                LOOP
                    -- Remove rel from PLT to LT
                    api.pkg_relationshipupdate.remove(b_4.relationshipid);

                    -- Relate the Branch to the Master
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_LicenseType',
                                'BranchLicenseType'),
                            t_lictypejobobjid,
                            b_4.masterltobjid);

                    --Set the ExpirationDate of the new Branch LT to the ExpirationDate of it's Master LT
                    api.pkg_columnupdate.setvalue(
                        t_lictypejobobjid,
                        'ExpiringMonth',
                        api.pkg_columnquery.VALUE(b_4.masterltobjid,
                                                  'ExpiringMonth'));
                    api.pkg_columnupdate.setvalue(
                        t_lictypejobobjid,
                        'ExpiringYear',
                        api.pkg_columnquery.VALUE(b_4.masterltobjid,
                                                  'ExpiringYear'));
                END LOOP;
            ------+++++

            END IF;                    -- Master/Branch License Type Candidate

            -- Now relate the License Type Job object to the License Type Category - Primary
            -- See what the Primary License Type from the Application has on it.

            FOR c_2
                IN (SELECT toobjectid ltcprimary
                      FROM api.relationships re
                     WHERE re.fromobjectid = t_pltobjectlist(c_1).objectid
                       AND re.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'o_PrimaryLicenseType',
                               'LicTypeCatPrimary')
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM api.relationships re2
                                 WHERE re2.fromobjectid = t_lictypejobobjid
                                   AND re2.toobjectid = re.toobjectid))
            LOOP
                -- Relate the License Type Category Primary to the License Type Job
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_LicenseType',
                            'LicTypeCatPrimary'),
                        t_lictypejobobjid,
                        c_2.ltcprimary);
            END LOOP;         -- c_2  Primary License Type to License Type Job

            --If Last IssueLicense process then else null
            /*if t_LastIssueLicenseProcess = 'Y' then
              --Loop through the PLTs that are related to an investigation.
              --Move the Investigation relationship to the new LT.
              for Inv in (select ai.RelationshipId AppInvRelId, ai.InvestigationJobId, iplt.RelationshipId ApplicPLTRelId, iplt.PrimaryLicenseTypeJobId
                            from query.r_ApplicationInvestigation ai
                            join query.r_InvestigationPriLicenseType iplt on iplt.InvestigationJobId = ai.InvestigationJobId
                           where iplt.PrimaryLicenseTypeJobId = t_PLTObjectList(c_1).ObjectId) loop
                --Move from the Application and Primary License Type
                api.pkg_relationshipupdate.Remove(inv.AppInvRelId, sysdate);
                api.pkg_Relationshipupdate.Remove(inv.applicpltrelid, sysdate);
                --To the New License and New License Type
                t_InvestigationRel := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName('j_Investigation', 'License'),
                                                                    Inv.Investigationjobid,
                                                                    t_LicObjectId);
                t_ApplicableLTInvRelId := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName('j_Investigation', 'LicenseType'),
                                                                    Inv.Investigationjobid,
                                                                    t_LicTypeJobObjId);
              end loop;
            end if; -- skip t_LastIssueLicneseProcess
     */
            -- Now relate the License Type Job object to any License Type Category - Secondary
            -- Look at the App Primary License Type which has a Secondary off it.
            FOR c_3
                IN (SELECT slt.licensetypecategoryobjectid secltobjid,
                           slt.licensetypecount,
                           slt.relationshipid,
                           r2.toobjectid                   issseccatrelid
                      FROM query.r_priltltcatsecondary  slt
                           JOIN api.relationships r
                               ON r.toobjectid =
                                  slt.licensetypecategoryobjectid --from LTC to PendingSLT
                              AND r.endpointid = t_psltendpointid
                           JOIN api.relationships r2
                               ON r2.toobjectid = r.fromobjectid
                              AND r2.endpointid = t_pltendpointid
                              AND r2.fromobjectid =
                                  slt.primarylicensetypeobjectid
                           JOIN query.r_issuelicenseplt iplt
                               ON iplt.primarylicensetypeobjectid =
                                  slt.primarylicensetypeobjectid
                     WHERE slt.primarylicensetypeobjectid =
                           t_pltobjectlist(c_1).objectid
                       AND (api.pkg_columnquery.VALUE(r.fromobjectid,
                                                      'Issue') =
                            'Y'
                         OR (api.pkg_columnquery.VALUE(
                                 iplt.issuelicenseprocessid,
                                 'IssueAllLicenseTypes') =
                             'Y'
                         AND slt.issued = 'N'))
                       AND api.pkg_columnquery.VALUE(slt.relationshipid,
                                                     'SStatus') NOT IN
                               (SELECT UPPER(s.description)
                                  FROM api.statuses  s
                                       JOIN api.jobstatuses js
                                           ON js.statusid = s.statusid
                                          AND js.jobtypeid =
                                              api.pkg_configquery.objectdefidforname(
                                                  'j_LicenseType')
                                 WHERE js.statustype IN ('C', 'X')))
            LOOP
                -- Set the Issued Boolean when the SLT is included in the Issue process.
                api.pkg_columnupdate.setvalue(c_3.relationshipid,
                                              'Issued',
                                              'Y');
                api.pkg_columnupdate.setvalue(c_3.issseccatrelid,
                                              'Issued',
                                              'Y');
                api.pkg_columnupdate.setvalue(c_3.relationshipid,
                                              'SStatus',
                                              'ISSUED');
                api.pkg_columnupdate.setvalue(c_3.issseccatrelid,
                                              'Status',
                                              'ISSUED');

                -- Relate the License Type Category to the License Type Job, to represent a Secondary License Type
                BEGIN
                    SELECT relationshipid
                      INTO t_newrelobjectid
                      FROM api.relationships
                     WHERE fromobjectid = t_lictypejobobjid
                       AND toobjectid = c_3.secltobjid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_LicenseType',
                               'LicTypeCatSecondary');
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'LicTypeCatSecondary'),
                                t_lictypejobobjid,
                                c_3.secltobjid);
                END;

                -- Set the Status date on the Secondary License Types
                t_statusdate   :=
                    api.pkg_columnquery.datevalue(c_3.relationshipid,
                                                  'StatusDate');
                api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                              'StatusDate',
                                              t_statusdate);

                -- Set the batch flags on the secondary license types
                pkg_batchtype.setbatchflags(
                    t_newrelobjectid,
                    a_includeinproducelicensebatch => 'Y',
                    a_includeindailybatch => 'Y');

                -- Set the Ready to Issue Date on the secondary license types
                api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                              'ReadyToIssueDate',
                                              t_readytoissuedate);

                -- Set the type of issueance on the secondary license types
                api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                              'TypeOfIssuance',
                                              'DOR');

                BEGIN                    -- License Type Count is not required
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'LicenseTypeCount',
                                                  c_3.licensetypecount);
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;

                FOR c_dup
                    IN (SELECT d.duplicateid objectid
                          FROM sitespecific.duplicate_t d
                         WHERE d.primarylicensetypeobjectid =
                               t_pltobjectlist(c_1).objectid
                           AND d.licensetypecategoryobjectid = c_3.secltobjid)
                LOOP
                    --Copy duplicate objects to License Type by setting the License Type Job ID
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'LicenseTypeJobId',
                                                  t_lictypejobobjid);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'RelationshipID',
                                                  t_newrelobjectid);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'IssueDate',
                                                  SYSDATE);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'ReadyToIssueDate',
                                                  t_readytoissuedate);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'TypeOfIssuance',
                                                  'DOR');
                END LOOP;
            END LOOP;       -- c_3  Secondary License Type to License Type Job

            --Mantain Dups on post verify
            api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                          'dup_IncludeInProduceLicBatchSe',
                                          'Y');
        END LOOP;         -- c_1  Primary License Types related to Application

        --Issue any Secondary LTs for existing License Types.
        sitespecific.pkg_issuelicense.issueslt(a_processobjid, a_appobjectid);

        -- if this is the Last IssueLicense process then else null end
        IF t_lastissuelicenseprocess = 'Y' THEN
            /*t_PLTObjectList.DELETE;  -- This is probably a very bad Idea,
                                       -- it would just be better to create a new array.

            select api.udt_object(r.LicenseTypeObjectId) PriLicTypeObjId
              bulk collect into t_PLTObjectList
              from query.r_appprimarylicensetype r
             where r.ApplicationObjectId = a_AppObjectId
               and api.pkg_columnquery.value(r.LicenseTypeObjectId, 'Status') not in
                  (select upper(s.Description)
                     from api.statuses s
                     join api.jobstatuses js
                       on js.StatusId = s.StatusId
                      and js.JobTypeId = api.pkg_configquery.ObjectDefIdForName('j_LicenseType')
                    where js.StatusType in ('C', 'X'));*/

            FOR plt
                IN                             --1..t_PLTObjectList.COUNT loop
                   (SELECT r.licensetypeobjectid
                               prilictypeobjid,
                           api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                                     'LicenseTypeCode')
                               ltcode
                      FROM query.r_appprimarylicensetype r
                     WHERE r.applicationobjectid = a_appobjectid
                       AND api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                                     'Status') NOT IN
                               (SELECT UPPER(s.description)
                                  FROM api.statuses  s
                                       JOIN api.jobstatuses js
                                           ON js.statusid = s.statusid
                                          AND js.jobtypeid =
                                              api.pkg_configquery.objectdefidforname(
                                                  'j_LicenseType')
                                 WHERE js.statustype IN ('C', 'X')))
            LOOP
                FOR inv
                    IN (SELECT ai.relationshipid   appinvrelid,
                               ai.investigationjobid,
                               iplt.relationshipid applicpltrelid,
                               iplt.primarylicensetypejobid
                          FROM query.r_applicationinvestigation  ai
                               JOIN query.r_investigationprilicensetype iplt
                                   ON iplt.investigationjobid =
                                      ai.investigationjobid
                         WHERE iplt.primarylicensetypejobid =
                               plt.prilictypeobjid /*t_PLTObjectList(PLT).ObjectId*/
                                                  )
                LOOP
                    --Move from the Application and Primary License Type
                    api.pkg_relationshipupdate.remove(inv.appinvrelid,
                                                      SYSDATE);
                    api.pkg_relationshipupdate.remove(inv.applicpltrelid,
                                                      SYSDATE);
                    --To the New License and New License Type
                    t_investigationrel   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Investigation',
                                'License'),
                            inv.investigationjobid,
                            t_licobjectid);

                    BEGIN
                        SELECT llt.licensetypejobid
                          INTO t_lictypejobobjid
                          FROM query.r_licenselicensetype llt
                         WHERE llt.licensejobid = t_licobjectid
                           AND api.pkg_columnquery.VALUE(
                                   llt.licensetypejobid,
                                   'LicenseTypeCode') =
                               plt.ltcode;

                        t_applicableltinvrelid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_Investigation',
                                    'LicenseType'),
                                inv.investigationjobid,
                                t_lictypejobobjid);
                    EXCEPTION
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'Investigation Move Fail: Error Relating the Investigation to a License Type. '
                                || SQLERRM);
                    END;
                END LOOP;
            END LOOP;                                              -- PLT Loop

            -- Find all related Investigations that was not related to a the Primary License Type
            -- then move it to the new License.
            FOR inv2 IN (SELECT ai.relationshipid, ai.investigationjobid
                           FROM query.r_applicationinvestigation ai
                          WHERE ai.applicationjobid = a_appobjectid)
            LOOP
                -- Move from the Application
                api.pkg_relationshipupdate.remove(inv2.relationshipid,
                                                  SYSDATE);
                -- To the New License
                t_investigationrel   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_Investigation',
                            'License'),
                        inv2.investigationjobid,
                        t_licobjectid);
            END LOOP;
        END IF;

        -- Find the Legal Entites on the Application
        IF t_licenseexists = 'N' THEN                -- skip is license exists
            BEGIN            -- Add Legal Entities from Application to License
                FOR c_le IN (SELECT toobjectid, endpointid
                               FROM api.relationships
                              WHERE fromobjectid = a_appobjectid
                                AND endpointid IN (t_applegalentityappepid,
                                                   t_applegalentityosmepid,
                                                   t_applegalentityflepid,
                                                   t_applegalentityp12epid,
                                                   t_applegalentityprip12id))
                LOOP
                    IF c_le.endpointid NOT IN
                           (t_applegalentityp12epid, t_applegalentityprip12id) THEN -- Copy the Legal Entity associated with the Application When not dealing with P12's
                        t_legalentityobjid   :=
                            pkg_legalentity.legalentitycopy(c_le.toobjectid);
                    ELSE -- The existing P12 legal entity will be related to the license or the Primary P12 Relationship will be copied.
                        t_legalentityobjid   := c_le.toobjectid;
                    END IF;

                    -- Get the endpoint for the rel from license to le
                    CASE
                        WHEN c_le.endpointid = t_applegalentityappepid THEN
                            t_createrelendpointid   := t_liclelicenseeepid;
                        WHEN c_le.endpointid = t_applegalentityosmepid THEN
                            t_createrelendpointid   := t_licleosmepid;
                        WHEN c_le.endpointid = t_applegalentityflepid THEN
                            t_createrelendpointid   := t_licleflepid; 
                        WHEN c_le.endpointid = t_applegalentityp12epid THEN
                            t_createrelendpointid   := t_liclep12epid;
                        WHEN c_le.endpointid = t_applegalentityprip12id --When looking at the Primary P12 Relationship Copy the rel
                                                                        THEN
                            t_createrelendpointid   := t_licleprip12epid;
                    END CASE;

                    -- Relate the Legal Entity to the License
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_createrelendpointid,
                                                       t_licobjectid,
                                                       t_legalentityobjid);
                END LOOP;                     -- Legal Entities on Application
            EXCEPTION
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'ERROR with Legal Entity.' || SQLERRM);
            END;                                             -- Legal Entities
        END IF;                                      ---Skip if license exists

        -- If the License already exists, remove the existing conditions before relating the current ones from the Application
        IF t_licenseexists = 'Y' THEN
            FOR c IN (SELECT r.relationshipid
                        FROM query.r_licensecondition r
                       WHERE r.licensejobid = t_licobjectid
                      UNION
                      SELECT a.relationshipid
                        FROM query.r_licenseadditioncondition a
                       WHERE a.licensejobid = t_licobjectid)
            LOOP
                api.pkg_relationshipupdate.remove(c.relationshipid);
            END LOOP;
        END IF;

        -- Copy Conditions to License
        t_endpointid   :=
            api.pkg_configquery.endpointidforname('j_License', 'Condition');

        FOR c IN (SELECT *
                    FROM query.r_applicationcondition r
                   WHERE r.applicationjobid = a_appobjectid)
        LOOP
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_licobjectid,
                                               c.conditionobjectid);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'DetailsCopied',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionText',
                                          c.conditiontext);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionCode',
                                          c.conditioncode);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionRelCount',
                                          c.conditionrelcount);
            api.pkg_columnupdate.setvalue(t_relationshipid, 'Sort', c.sort);
        END LOOP;

        -- Copy Additional Conditions to License
        t_endpointid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'AdditCondition');
        t_objectdefid   :=
            api.pkg_configquery.objectdefidforname('o_AdditionalCondition');

        FOR x
            IN (SELECT ac.objectid, ac.sort2, ac.conditiontext
                  FROM query.r_applicationadditioncondition  r
                       JOIN query.o_additionalcondition ac
                           ON ac.objectid = r.additionalconditionobjectid
                 WHERE r.applicationjobid = a_appobjectid)
        LOOP
            t_newobjectid   := api.pkg_objectupdate.new(t_objectdefid);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'ConditionText',
                                          x.conditiontext);
            api.pkg_columnupdate.setvalue(t_newobjectid, 'Sort2', x.sort2);
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_licobjectid,
                                               t_newobjectid);
        END LOOP;
    END issueoriginallicense;


    ----------------------------------------------------------------------------------------------------
    --  IssueTransferLicense() -- PUBLIC                             EDIT THESE NOTES
    -- Create new license based on parameter from the application job.
    -- Cancel existing License Type Job(s) and License when Transfer is done,
    --   using processes p_TerminateLicenseType, p_TerminateLicense.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE issuetransferlicense(a_appobjectid   udt_id,
                                   a_processobjid  udt_id DEFAULT NULL)
    IS
        --  t_TransFromP12Count         number;
        --  t_NewP12MasterLicId         udt_Id;
        t_testrelid   VARCHAR2(500);
        t_skip        BOOLEAN;
    BEGIN
        t_appdefid                    :=
            api.pkg_configquery.objectdefidforname('j_Application');
        t_applicreldefid              :=
            api.pkg_configquery.objectdefidforname('r_ApplicationLicense');

        t_dbadefid                    := api.pkg_configquery.objectdefidforname('o_DBANames');
        t_appdbanamesreldefid         :=
            api.pkg_configquery.objectdefidforname('r_ApplicationDBANames');
        t_licdbanamesreldefid         :=
            api.pkg_configquery.objectdefidforname('r_LicenseDBANames');


        t_applegalentityappepid       :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Applicant');
        t_applegalentityosmepid       :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'OnSaleManager');
        t_applegalentityflepid        :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'FoodLesseeApp');   -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
        t_applegalentityp12epid       :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'P12Applicant');
        t_applegalentityprip12id      :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'PrimaryP12Applicant');

        t_lastissuelicenseprocess     :=
            api.pkg_columnquery.VALUE(a_processobjid, 'IsIssueAllLTs');

        t_liclelicenseeepid           :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'LicenseeLegalEntity');
        t_licleosmepid                :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'OSMLegalEntity');
        t_licleflepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'FoodLesseeLic');    -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
        t_liclep12epid                :=
            api.pkg_configquery.endpointidforname('j_License', 'P12Licensee');
        t_licleprip12epid             :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'PrimaryP12Licensee');

        t_licdefid                    :=
            api.pkg_configquery.objectdefidforname('j_License');
        t_lictypedefid                :=
            api.pkg_configquery.objectdefidforname('j_LicenseType');

        t_priltltcatprimaryreldef     :=
            api.pkg_configquery.objectdefidforname('r_PriLTLTCatPrimary');
        t_priltltcatsecondaryreldef   :=
            api.pkg_configquery.objectdefidforname('r_PriLTLTCatSecondary');

        t_appprilictypereldef         :=
            api.pkg_configquery.objectdefidforname('r_AppPrimaryLicenseType');


        t_apppremaddrreldefid         :=
            api.pkg_configquery.objectdefidforname('r_ApplicationPremAddr');

        t_licaddrpremreldefid         :=
            api.pkg_configquery.objectdefidforname('r_LicenseAddrPremises');

        t_liclictypereldefid          :=
            api.pkg_configquery.objectdefidforname('r_LicenseLicenseType');
        t_lictypltcatprireldefid      :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseTypeLTCatPrimary');
        t_lictypltcatsecreldefid      :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseTypeLTCatSecondary');
        t_lictxfrfromreldefid         :=
            api.pkg_configquery.objectdefidforname(
                'r_ApplicationLicenseTransfer');
        t_licensejobids               := api.udt_objectlist();

        t_psltendpointid              :=
            api.pkg_configquery.endpointidforname(
                'o_PendingSecondaryLicenseType',
                'PendLicTypeCatSecondary');
        t_pltendpointid               :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'PendSecLicType');


        SELECT       -- grab everything we need to know about the application.
               applicationtype,
               licensenumber,
               licensetransferringfrom,
               licensebeingchanged,
               licensenumberbeingchanged,
               persontoperson,
               premisetopremise,
               fiduciarytransfer,
               fiduciarytype,
               licensetypeexchange,
               droppartner,
               basefileoffice,
               istemporarymailingaddress,
               externalfilenum,
               ispriorityapplication
          INTO t_applicationtype,
               t_licensenumber,
               t_licensetransferringfrom,
               t_licensebeingchanged,
               t_licensenumberbeingchanged,
               t_persontoperson,
               t_premisetopremise,
               t_fiduciarytransfer,
               t_fiduciarytype,
               t_licensetypeexchange,
               t_droppartner,
               t_basefileofc,
               t_tempaddr,
               t_appexternalfilenum,
               t_priorityapplication
          FROM query.j_application
         WHERE objectid = a_appobjectid;

        -- Get the objectid for the license being transferred
        SELECT c.fromobjectid
          INTO t_lictxfrfromobjid
          FROM api.relationships c
         WHERE c.toobjectid = a_appobjectid
           AND c.relationshipdefid = t_lictxfrfromreldefid;

        -- !! RAISE ERROR IF TRANS FROM LICENSE IS A P12 MASTER !! --
        IF api.pkg_columnquery.VALUE(t_lictxfrfromobjid,
                                     'ThisLicenseIsP12Master') =
           'Y' THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'You cannot transfer a P12 Master License. Please change the P12 Master License for '
                || api.pkg_columnquery.VALUE(t_lictxfrfromobjid,
                                             'PrimaryLicensee')
                || '.');
        END IF;

        BEGIN
            SELECT al.licensejobid, 'Y'
              INTO t_licobjectid, t_licenseexists
              FROM query.r_applicationlicense al
             WHERE al.applicationjobid = a_appobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- create new License object and relate the application
                t_licobjectid      := api.pkg_objectupdate.new(t_licdefid);

                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'License'),
                        a_appobjectid,
                        t_licobjectid);

                -- Copy stored dynamic details from existing Application job to
                -- the details of the new License job
                pkg_copy.copystoredobjdetailsexception(
                    a_appobjectid,
                    t_licobjectid,
                    'StatusDate,IsGeocoded');

                -- Copy ExternalFileNum of Application to ExternalFileNum of License
                t_licensenumber    := (SUBSTR(t_appexternalfilenum, 1, 6));
                api.pkg_jobupdate.setexternalfilenum(t_licobjectid,
                                                     t_licensenumber);
        END;

        -- All Issue License processes run after the First one
        -- will only copy License Types to the existing License.
        IF t_licenseexists = 'N' THEN
            FOR c
                IN (SELECT toobjectid dbaappobjid
                      FROM api.relationships
                     WHERE fromobjectid = a_appobjectid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'DBANames'))
            LOOP
                -- create a DBA object to associate with the license
                t_dbanewobjid   := api.pkg_objectupdate.new(t_dbadefid);

                -- Copy stored dynamic details from existing DBA Object to the
                -- the details of the new DBA object
                pkg_copy.copystoredobjectdetails(c.dbaappobjid,
                                                 t_dbanewobjid);

                -- relate the DBA to the license
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('j_License',
                                                              'DBANames'),
                        t_licobjectid,
                        t_dbanewobjid);
            END LOOP;                                                    --dba

            -- dba from app copied to lic

            BEGIN                       -- relate Base File Office to License.
                -- find the Office Code from the application
                SELECT basefileofficeid
                  INTO t_basefileofcobjid
                  FROM query.j_application
                 WHERE objectid = a_appobjectid;

                -- relate the office to the license
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_License',
                            'LicenseToOffice'),
                        t_licobjectid,
                        t_basefileofcobjid);
            EXCEPTION
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'ERROR with Base File Office. ' || SQLERRM);
            END;                                  -- relate Office to License.

            BEGIN
                --Always Copy the Premises Address from the Application to the new License
                SELECT toobjectid
                  INTO t_premaddrobjectid
                  FROM api.relationships
                 WHERE fromobjectid = a_appobjectid
                   AND endpointid =
                       api.pkg_configquery.endpointidforname('j_Application',
                                                             'Premises');

                -- Relate Premises Address object to Application
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('j_License',
                                                              'Premises'),
                        t_licobjectid,
                        t_premaddrobjectid);

                IF api.pkg_columnquery.VALUE(t_premaddrobjectid,
                                             'EligibleForTransfer') =
                   'Y' THEN
                    api.pkg_columnupdate.removevalue(t_premaddrobjectid,
                                                     'EligibleForTransfer');
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'ERROR with Existing Premises Address. ' || SQLERRM);
            END;

             BEGIN
             -- Email Address Added by Pawan WO 20669 for transfer apps --3/27/2020
                --Always Copy the Email Address from the Application to the new License
                SELECT toobjectid
                  INTO t_emailaddrobjectid
                  FROM api.relationships
                 WHERE fromobjectid = a_appobjectid
                   AND endpointid =
                       api.pkg_configquery.endpointidforname('j_Application',
                                                             'ApplicationEmail');

                -- Relate Email Address object to License
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('j_License',
                                                              'LicenseEmail'),
                        t_licobjectid,
                        t_emailaddrobjectid);
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                    t_newrelobjectid   := NULL;
            END;

            --End Added by Pawan WO 20669 for transfer apps --3/27/2020
            -- Find the current revision of Conditions Document ABC-172 (if exists), and relate to License
            BEGIN
                t_abc172docid := GetConditionalDoc(a_appobjectid);
                IF t_abc172docid IS NOT NULL THEN
                    t_endpointid   :=
                        api.pkg_configquery.endpointidforname(
                            'j_License',
                            'ABCWordDocument');
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_endpointid,
                                                       t_licobjectid,
                                                       t_abc172docid);
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL; -- Conditions document is optional, so just move on.
            END;


            BEGIN                        -- Legal Entities and mailing address
                IF 'N' = 'Y' THEN -- Copy existing Legal Entity from existing License to new License
                    FOR c_le2
                        IN (SELECT toobjectid leobjectid, endpointid
                              FROM api.relationships
                             WHERE fromobjectid = t_lictxfrfromobjid
                               AND endpointid IN
                                       (t_liclelicenseeepid,
                                        t_licleosmepid,
                                        t_licleflepid,
                                        t_liclep12epid))
                    LOOP
                        IF c_le2.endpointid <> t_liclep12epid THEN -- Copy the Legal Entity associated with the Application
                            -- Copy the Legal Entity from the existing License
                            t_legalentityobjid   :=
                                pkg_legalentity.legalentitycopy(
                                    c_le2.leobjectid);
                        ELSE -- the existing P12 legal entity will be related to the license.
                            t_legalentityobjid   := c_le2.leobjectid;
                        END IF;

                        -- Relate the new Legal Entity to the new License
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                c_le2.endpointid,
                                t_licobjectid,
                                t_legalentityobjid);
                    END LOOP;            -- Legal Entities on existing License
                ELSE -- Copy Legal Entities from Application and relate to new license
                    FOR c_le
                        IN (SELECT toobjectid, endpointid
                              FROM api.relationships
                             WHERE fromobjectid = a_appobjectid
                               AND endpointid IN (t_applegalentityappepid,
                                                  t_applegalentityosmepid,
                                                  t_applegalentityflepid,
                                                  t_applegalentityp12epid,
                                                  t_applegalentityprip12id))
                    LOOP
                        IF c_le.endpointid NOT IN
                               (t_applegalentityp12epid,
                                t_applegalentityprip12id) THEN -- Copy the Legal Entity associated with the Application
                            t_legalentityobjid   :=
                                pkg_legalentity.legalentitycopy(
                                    c_le.toobjectid);
                        ELSE -- the existing P12 legal entity will be related to the license.
                            t_legalentityobjid   := c_le.toobjectid;
                        END IF;

                        -- Get the endpoint for the rel from license to le
                        CASE
                            WHEN c_le.endpointid = t_applegalentityappepid THEN 
                                t_createrelendpointid   :=
                                    t_liclelicenseeepid;
                            WHEN c_le.endpointid = t_applegalentityosmepid THEN
                                t_createrelendpointid   := t_licleosmepid;
                            WHEN c_le.endpointid = t_applegalentityflepid THEN
                                t_createrelendpointid   := t_licleflepid;
                            WHEN c_le.endpointid = t_applegalentityp12epid THEN
                                t_createrelendpointid   := t_liclep12epid;
                            WHEN c_le.endpointid = t_applegalentityprip12id --When looking at the Primary P12 Relationship Copy the rel
                                                                            THEN
                                t_createrelendpointid   := t_licleprip12epid;
                        END CASE;

                        -- Relate the Legal Entity to the License
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                t_createrelendpointid,
                                t_licobjectid,
                                t_legalentityobjid);
                    END LOOP;                 -- Legal Entities on Application
                END IF;   -- Transfer App does not have Legal Entity component

                BEGIN -- relate the Mailing Address to the license, if it is not temporary
                    SELECT r.toobjectid
                      INTO t_mailaddrobjectid
                      FROM api.relationships r
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'MailingAddress')
                       AND r.fromobjectid = a_appobjectid;

                    -- if not a temporary address and this is not a P12 application then create the Mailing Address Rel
                    IF t_tempaddr <> 'Y'
                   AND p12applicantcount(a_appobjectid) = 0 THEN
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_License',
                                    'MailingAddress'),
                                t_licobjectid,
                                t_mailaddrobjectid);
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_newrelobjectid   := NULL;
                END;
            END;                         -- Legal Entities and mailing address
        END IF;                                        -- t_LicenseExists skip

        BEGIN                                                 -- License Types
            -- Create one License Type Job for each Primary License Type found on Application.
            -- Copy stored details on Primary License Type to License Type Job.
            -- Set Batch flag "IncludeInBatch".
            -- Relate to the License Job to each License Type Job.
            -- Find the relationships between each Primary License Type and
            --  1. License Type Category for Primary License Type
            --  2. License Type Category for Secondary License Type
            -- For every Primary License Type related to an investigation (for reports)
            -- Move the Investigation from the Application to the New License.

            -- Get the ready to issue date from the Application
            t_readytoissuedate   :=
                api.pkg_columnquery.datevalue(a_appobjectid,
                                              'ReadyToIssueDate');



            FOR c_1
                IN (SELECT -- Grab all Non-Completed/Cancelled PrimaryLicenseTypes from the app
                           r.fromobjectid
                               prilictypeobjid,
                           api.pkg_columnquery.VALUE(r.fromobjectid,
                                                     'LicenseTypeCode')
                               licensetypecode,
                           api.pkg_columnquery.VALUE(r.fromobjectid,
                                                     'TransFromLTCode')
                               licensetypecodetrans,
                           api.pkg_columnquery.VALUE(r.fromobjectid,
                                                     'TypeOfIssuance')
                               typeofissuance,
                           api.pkg_columnquery.VALUE(r.fromobjectid,
                                                     'IsTransferred')
                               istransferred,
                           api.pkg_columnquery.VALUE(r.fromobjectid,
                                                     'BranchApplies')
                               branchapplies
                      FROM api.relationships  r
                           JOIN api.relationships ilt
                               ON ilt.fromobjectid = a_processobjid
                              AND ilt.toobjectid = r.fromobjectid
                     WHERE r.toobjectid = a_appobjectid
                       AND r.relationshipdefid = t_appprilictypereldef
                       AND ilt.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'p_IssueLicense',
                               'PrimaryLicenseType')
                       AND (api.pkg_columnquery.VALUE(ilt.relationshipid,
                                                      'Issue') =
                            'Y'
                         OR (api.pkg_columnquery.VALUE(
                                 ilt.fromobjectid,
                                 'IssueAllLicenseTypes') =
                             'Y'
                         AND api.pkg_columnquery.VALUE(r.fromobjectid,
                                                       'Issued') =
                             'N'))
                       AND api.pkg_columnquery.VALUE(r.fromobjectid,
                                                     'Status') NOT IN
                               (SELECT UPPER(s.description)
                                  FROM api.statuses  s
                                       JOIN api.jobstatuses js
                                           ON js.statusid = s.statusid
                                          AND js.jobtypeid =
                                              api.pkg_configquery.objectdefidforname(
                                                  'j_LicenseType')
                                 WHERE js.statustype IN ('C', 'X')))
            LOOP
                BEGIN
                    SELECT jobid
                      INTO t_lictypejobobjid
                      FROM api.jobs
                     WHERE externalfilenum =
                              api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                                        'LicenseTypeCode')
                           || '-'
                           || api.pkg_columnquery.VALUE(t_licobjectid,
                                                        'ExternalFileNum')
                       AND jobtypeid = t_lictypedefid;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- Create new License Type Object
                        t_lictypejobobjid   :=
                            api.pkg_objectupdate.new(
                                api.pkg_configquery.objectdefidforname(
                                    'j_LicenseType'));

                        -- Relate the License Type Job to the License
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_License',
                                    'LicenseType'),
                                t_licobjectid,
                                t_lictypejobobjid);

                        -- Log the Transfer with the License Transfers object
                        IF c_1.istransferred = 'Y' THEN
                            pkg_issuelicense.loglicensetransfer(
                                t_lictypejobobjid,
                                c_1.licensetypecode,
                                t_licensenumber,
                                c_1.prilictypeobjid,
                                a_appobjectid);
                        END IF;
                END;

                -- Set the Issued Boolean when the PLT is included in the Issue process.
                api.pkg_columnupdate.setvalue(c_1.prilictypeobjid,
                                              'Issued',
                                              'Y');
                api.pkg_columnupdate.setvalue(c_1.prilictypeobjid,
                                              'Status',
                                              'ISSUED');

                -- Copy stored details from Primary License Type object to License Type Job
                pkg_copy.copystoredobjectdetails(c_1.prilictypeobjid,
                                                 t_lictypejobobjid);

                -- Copy the Ready to Issue date from the Application to the License Types
                api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                              'ReadyToIssueDate',
                                              t_readytoissuedate);

                -- Copy the Type of Issuance from the Primary License Type to the License Types
                api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                              'TypeofIssuance',
                                              c_1.typeofissuance);

                -- Set the batch flags
                pkg_batchtype.setbatchflags(
                    a_lictypejobid => t_lictypejobobjid,
                    a_includeinproducelicensebatch => 'Y',
                    a_includeindailybatch => 'Y');

                -- Set Expiring Month and Year
                pkg_issuelicense.setexpmonthyear(a_appobjectid,
                                                 SYSDATE,
                                                 c_1.prilictypeobjid,
                                                 t_lictypejobobjid);

                -- Now relate the License Type Job object to the License Type Category - Primary
                -- See what the Primary License Type from the Application has on it.
                FOR c_2
                    IN (SELECT fromobjectid
                          FROM api.relationships
                         WHERE relationshipdefid = t_priltltcatprimaryreldef
                           AND toobjectid = c_1.prilictypeobjid)
                LOOP
                    -- Relate the License Type Category to the License Type Job
                    BEGIN
                        SELECT relationshipid
                          INTO t_newrelobjectid
                          FROM api.relationships
                         WHERE fromobjectid = t_lictypejobobjid
                           AND toobjectid = c_2.fromobjectid
                           AND endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_LicenseType',
                                   'LicTypeCatPrimary');
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'LicTypeCatPrimary'),
                                    t_lictypejobobjid,
                                    c_2.fromobjectid);
                    END;
                END LOOP;          -- Primary License Type to License Type Job

                -- Now relate the License Type Job to any License Type Category - Secondary
                -- See what the Primary License Type (for Secondary LTs) from the Application has on it.
                FOR c_3
                    IN (SELECT slt.primarylicensetypeobjectid  fromobjectid,
                               slt.licensetypecategoryobjectid secltobjid,
                               slt.relationshipid              relidappsec,
                               r2.toobjectid                   relidissusec,
                               slt.istransferred               istransferred,
                               slt.fromslt
                          FROM query.r_priltltcatsecondary  slt
                               JOIN api.relationships r
                                   ON r.toobjectid =
                                      slt.licensetypecategoryobjectid --from LTC to PendingSLT
                                  AND r.endpointid = t_psltendpointid
                               JOIN api.relationships r2
                                   ON r2.toobjectid = r.fromobjectid
                                  AND r2.endpointid = t_pltendpointid
                                  AND r2.fromobjectid =
                                      slt.primarylicensetypeobjectid
                               JOIN query.r_issuelicenseplt iplt
                                   ON iplt.primarylicensetypeobjectid =
                                      slt.primarylicensetypeobjectid
                         WHERE slt.primarylicensetypeobjectid =
                               c_1.prilictypeobjid
                           AND (api.pkg_columnquery.VALUE(r.fromobjectid,
                                                          'Issue') =
                                'Y'
                             OR (api.pkg_columnquery.VALUE(
                                     iplt.issuelicenseprocessid,
                                     'IssueAllLicenseTypes') =
                                 'Y'
                             AND slt.issued = 'N'))
                           AND api.pkg_columnquery.VALUE(slt.relationshipid,
                                                         'SStatus') NOT IN
                                   (SELECT UPPER(s.description)
                                      FROM api.statuses  s
                                           JOIN api.jobstatuses js
                                               ON js.statusid = s.statusid
                                              AND js.jobtypeid =
                                                  api.pkg_configquery.objectdefidforname(
                                                      'j_LicenseType')
                                     WHERE js.statustype IN ('C', 'X')))
                LOOP
                    -- Set the Issued Boolean when the SLT is included in the Issue process.
                    api.pkg_columnupdate.setvalue(c_3.relidappsec,
                                                  'Issued',
                                                  'Y');
                    api.pkg_columnupdate.setvalue(c_3.relidissusec,
                                                  'Issued',
                                                  'Y');
                    api.pkg_columnupdate.setvalue(c_3.relidappsec,
                                                  'SStatus',
                                                  'ISSUED');
                    api.pkg_columnupdate.setvalue(c_3.relidissusec,
                                                  'Status',
                                                  'ISSUED');

                    -- Relate the License Type Category to the License Type Job
                    BEGIN
                        SELECT relationshipid
                          INTO t_newrelobjectid
                          FROM api.relationships
                         WHERE fromobjectid = t_lictypejobobjid
                           AND toobjectid = c_3.secltobjid
                           AND endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_LicenseType',
                                   'LicTypeCatSecondary');
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'LicTypeCatSecondary'),
                                    t_lictypejobobjid,
                                    c_3.secltobjid);
                    END;

                    -- Set the Status Date adn Status on the Secondary License Types
                    t_statusdate   :=
                        api.pkg_columnquery.datevalue(c_3.relidappsec,
                                                      'StatusDate');
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'StatusDate',
                                                  t_statusdate);

                    -- Copy License Type Count detail onto the relationship
                    pkg_copy.copystoredobjectdetails(c_3.relidappsec,
                                                     t_newrelobjectid);

                    -- Set the Status Date adn Status on the Secondary License Types
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'Status',
                                                  'PENDING');

                    -- Set the batch flags on the secondary license types
                    pkg_batchtype.setbatchflags(
                        t_newrelobjectid,
                        a_includeinproducelicensebatch => 'Y',
                        a_includeindailybatch => 'Y');

                    -- Set the Ready to Issue Date on the secondary license types
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'ReadyToIssueDate',
                                                  t_readytoissuedate);

                    -- Set the type of issueance on the secondary license types
                    IF c_3.istransferred = 'N' THEN
                        api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                      'TypeOfIssuance',
                                                      'DOR');
                    ELSE
                        SELECT REGEXP_REPLACE(c_1.typeofissuance,
                                              '[[:digit:]]{2}',
                                              c_3.fromslt,
                                              1,
                                              1)
                          INTO t_sectypeofissuance
                          FROM DUAL;

                        api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                      'TypeOfIssuance',
                                                      t_sectypeofissuance);
                    --api.pkg_columnupdate.SetValue(t_NewRelObjectId,'TypeOfIssuance', c_1.typeofissuance);
                    END IF;

                    --api.pkg_errors.RaiseError(-20001, 'A)PriLicTypeObjId: ' || c_1.PriLicTypeObjId || ', SecLTObjId (FromObjectID): ' || c_3.FromObjectId); --Testing Only
                    FOR c_dup
                        IN (SELECT d.duplicateid objectid
                              FROM sitespecific.duplicate_t d
                             WHERE d.primarylicensetypeobjectid =
                                   c_1.prilictypeobjid
                               AND d.licensetypecategoryobjectid =
                                   c_3.secltobjid)
                    LOOP
                        --Copy duplicate objects to License Type by setting the License Type Job ID
                        api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                      'LicenseTypeJobId',
                                                      t_lictypejobobjid);
                        api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                      'RelationshipID',
                                                      t_newrelobjectid);
                        api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                      'IssueDate',
                                                      SYSDATE);
                        api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                      'ReadyToIssueDate',
                                                      t_readytoissuedate);
                        api.pkg_columnupdate.removevalue(c_dup.objectid,
                                                         'BatchDate'); -- Gurpreet -- Issue # 2528 (ABC# 1915) ; Dup on Transfers Apps were not printing or earning in Daily Batch. Print Flag was not being updated, In PKG_BatchType.ProduceLicenses (if (dup_l.batchdate is null and t_DailyorRenewal = 'Daily'))

                        IF c_3.istransferred = 'N' THEN
                            api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                          'TypeOfIssuance',
                                                          'DOR');
                        ELSE
                            SELECT REGEXP_REPLACE(c_1.typeofissuance,
                                                  '[[:digit:]]{2}',
                                                  c_3.fromslt,
                                                  1,
                                                  1)
                              INTO t_sectypeofissuance
                              FROM DUAL;

                            api.pkg_columnupdate.setvalue(
                                c_dup.objectid,
                                'TypeOfIssuance',
                                t_sectypeofissuance);
                        --api.pkg_columnupdate.SetValue(c_dup.objectid,'TypeOfIssuance', c_1.typeofissuance);
                        END IF;
                    END LOOP;
                END LOOP;        -- Secondary License Type to License Type Job

                --Mantain Dups on post verify
                api.pkg_columnupdate.setvalue(
                    t_lictypejobobjid,
                    'dup_IncludeInProduceLicBatchSe',
                    'Y');

                -- Master/Branch License Type Candidate
                IF c_1.branchapplies = 'Y'
               AND c_1.istransferred = 'N' THEN
                    FOR b_1
                        IN (SELECT toobjectid masterltobjid, relationshipid
                              FROM api.relationships
                             WHERE fromobjectid = c_1.prilictypeobjid
                               AND endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'MasterLicenseType'))
                    LOOP
                        -- Remove rel from PLT to LT
                        api.pkg_relationshipupdate.remove(b_1.relationshipid);
                        api.pkg_columnupdate.setvalue(c_1.prilictypeobjid,
                                                      'IsBranchS',
                                                      'Y');

                        -- Relate the Branch to the Master
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'MasterLicenseType')  --t_MstrBranchLTEPId
                                                        ,
                                t_lictypejobobjid,
                                b_1.masterltobjid);

                        --Set the ExpirationDate of the new Branch LT to the ExpirationDate of it's Master LT
                        api.pkg_columnupdate.setvalue(
                            t_lictypejobobjid,
                            'ExpiringMonth',
                            api.pkg_columnquery.VALUE(b_1.masterltobjid,
                                                      'ExpiringMonth'));
                        api.pkg_columnupdate.setvalue(
                            t_lictypejobobjid,
                            'ExpiringYear',
                            api.pkg_columnquery.VALUE(b_1.masterltobjid,
                                                      'ExpiringYear'));
                    END LOOP;

                    --get the relationship of when the issuing PLT is related to a Master PLT  Copy it over and remove the previous rel from the original Branch PLT to the Master PLT
                    FOR b_2
                        IN (SELECT r.toobjectid     masterplt,
                                   r.relationshipid tomasterrelid
                              FROM api.relationships r
                             WHERE r.fromobjectid = c_1.prilictypeobjid
                               AND r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'BranchtoMaster'))
                    LOOP
                        --Create the new relationship from the Branch j_LicenseType to the Master PLT
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'MasterBranchLicenseType'),
                                t_lictypejobobjid,
                                b_2.masterplt);
                        --remove the relationship from the previous Branch PLT to the Master PLT
                        api.pkg_relationshipupdate.remove(b_2.tomasterrelid);
                        api.pkg_columnupdate.setvalue(c_1.prilictypeobjid,
                                                      'IsBranchS',
                                                      'Y');
                    END LOOP;                 --to Master Primary License Type

                    --get the relationship of when the issuing PLT is related to a Branch PLT
                    --Copy it over and remove the previous rel from the original Master PLT to the Branch PLT
                    FOR b_3
                        IN (SELECT r.toobjectid branchplt, r.relationshipid
                              FROM api.relationships r
                             WHERE r.fromobjectid = c_1.prilictypeobjid
                               AND r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'MastertoBranch'))
                    LOOP
                        --Create the new relationship from the Master j_LicenseType to the Branch PLT
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'BranchPrimaryLicenseType'),
                                t_lictypejobobjid,
                                b_3.branchplt);
                        --remove the relationship from the previous Branch PLT to the Master PLT
                        api.pkg_relationshipupdate.remove(b_3.relationshipid);
                    END LOOP;                 --to Master Primary License Type

                    ------+++++ PLT is a Master of a Branch License Type
                    FOR b_4
                        IN (SELECT toobjectid masterltobjid, relationshipid
                              FROM api.relationships
                             WHERE fromobjectid = c_1.prilictypeobjid
                               AND endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'MasterPrimaryLicenseType'))
                    LOOP
                        -- Remove rel from PLT to LT
                        api.pkg_relationshipupdate.remove(b_4.relationshipid);

                        -- Relate the Branch to the Master
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'BranchLicenseType'),
                                t_lictypejobobjid,
                                b_4.masterltobjid);

                        --Set the ExpirationDate of the new Branch LT to the ExpirationDate of it's Master LT
                        api.pkg_columnupdate.setvalue(
                            t_lictypejobobjid,
                            'ExpiringMonth',
                            api.pkg_columnquery.VALUE(b_4.masterltobjid,
                                                      'ExpiringMonth'));
                        api.pkg_columnupdate.setvalue(
                            t_lictypejobobjid,
                            'ExpiringYear',
                            api.pkg_columnquery.VALUE(b_4.masterltobjid,
                                                      'ExpiringYear'));
                    END LOOP;
                ------+++++
                ELSIF c_1.branchapplies = 'Y'
                  AND c_1.istransferred = 'Y' THEN
                    /*Begin Master/Branch*/
                    --copy Master relationship from the o_PLT(s) to the new j_LT(s)
                    --get the Branch j_LT JobId that the o_PLT is related to...
                    FOR c_4
                        IN (SELECT r1.toobjectid
                                       branchid,
                                   r1.relationshipid
                                       branchltmasterplt,
                                   r2.relationshipid
                                       branchtomasterltrelid,
                                   r2.toobjectid
                                       oldmasterltid,
                                   (SELECT l.toobjectid licensejobid
                                      FROM api.relationships l
                                     WHERE l.fromobjectid = r1.toobjectid
                                       AND l.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'j_LicenseType',
                                               'License'))
                                       licensejobid
                              FROM api.relationships  r1
                                   JOIN api.relationships r2
                                       ON r2.fromobjectid = r1.toobjectid
                                      AND r2.endpointid =
                                          api.pkg_configquery.endpointidforname(
                                              'j_LicenseType',
                                              'MasterLicenseType')
                             WHERE r1.fromobjectid = c_1.prilictypeobjid
                               AND r1.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'MasterPrimaryLicenseType'))
                    LOOP
                        --loop through the o_PLTs that are related to the "old" Master j_LT, where the o_PLTs Application is a Transfer or Change and it's status Type is I or O
                        FOR m
                            IN (SELECT DISTINCT
                                       r3.toobjectid
                                           branchprilts,
                                       r3.relationshipid
                                           branchplttomasterltid,
                                       (SELECT r5.toobjectid
                                          FROM api.relationships r5
                                         WHERE r5.fromobjectid =
                                               r4.toobjectid
                                           AND r5.endpointid IN
                                                   (api.pkg_configquery.endpointidforname(
                                                        'j_Application',
                                                        'LicenseTransfer'),
                                                    api.pkg_configquery.endpointidforname(
                                                        'j_Application',
                                                        'LicenseUpgrade')))
                                           licensejobid --grab the Transfer From and Upgrade From licensejobid
                                  FROM api.relationships  r3
                                       JOIN api.relationships r4
                                           ON r4.fromobjectid = r3.toobjectid
                                          AND r4.endpointid =
                                              api.pkg_configquery.endpointidforname(
                                                  'o_PrimaryLicenseType',
                                                  'Application')
                                       JOIN query.j_application a
                                           ON a.objectid = r4.toobjectid
                                       JOIN api.jobstatuses s
                                           ON s.statusid = a.statusid
                                 WHERE r3.fromobjectid = c_4.oldmasterltid
                                   AND r3.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'j_LicenseType',
                                           'BranchPrimaryLicenseType')
                                   AND a.applicationtype <> 'Original'
                                   AND s.statustype IN ('I', 'O'))
                        LOOP
                            --Add the License Jobids to an array that will be used to make sure I don't also update the related Branch j_LT
                            t_licensejobids.EXTEND(1);
                            t_licensejobids(t_licensejobids.COUNT)   :=
                                api.udt_object(m.licensejobid);
                            --delete the old rel from the Branch o_PLT to the Master j_LT so that we can create a new one
                            api.pkg_relationshipupdate.remove(
                                m.branchplttomasterltid);
                            --Set new relationships from old Branch o_PLT to NEW Master j_LT
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'BranchPrimaryLicenseType'),
                                    t_lictypejobobjid,
                                    m.branchprilts);
                            --set the Expiration date on the Branch LTs to reflect the Exp. Date on it's Master
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringMonth',
                                api.pkg_columnquery.VALUE(m.branchprilts,
                                                          'ExpiringMonth'));
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringYear',
                                api.pkg_columnquery.VALUE(m.branchprilts,
                                                          'ExpiringYear'));
                            t_skip   := TRUE;
                        END LOOP;

                        IF t_licensejobids.COUNT > 0 THEN
                            FOR c IN 1 .. t_licensejobids.COUNT
                            LOOP
                                IF c_4.licensejobid =
                                   t_licensejobids(c).objectid --If the Transfer o_PLT for this License has already been updated
                                                               THEN
                                    NULL;
                                ELSE
                                    --delete the relationship from the Branch j_LT to the old Master j_LT
                                    api.pkg_relationshipupdate.remove(
                                        c_4.branchtomasterltrelid);
                                    --Create the relationship from the New Master j_LicenseType to the old Branch j_LicenseType
                                    t_newrelobjectid   :=
                                        api.pkg_relationshipupdate.new(
                                            api.pkg_configquery.endpointidforname(
                                                'j_LicenseType',
                                                'BranchLicenseType'),
                                            t_lictypejobobjid,
                                            c_4.branchid);
                                    --set the Expiration Date on the Branch LTs to reflect the new Master LT's Exp Date
                                    api.pkg_columnupdate.setvalue(
                                        t_lictypejobobjid,
                                        'ExpiringMonth',
                                        api.pkg_columnquery.VALUE(
                                            c_1.prilictypeobjid,
                                            'ExpiringMonth'));
                                    api.pkg_columnupdate.setvalue(
                                        t_lictypejobobjid,
                                        'ExpiringYear',
                                        api.pkg_columnquery.VALUE(
                                            c_1.prilictypeobjid,
                                            'ExpiringYear'));
                                END IF;             --If ids have been updated
                            END LOOP;                      --end LicenseJobIds
                        ELSE
                            --delete the relationship from the Branch j_LT to the old Master j_LT
                            api.pkg_relationshipupdate.remove(
                                c_4.branchtomasterltrelid);
                            --Create the new rel
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'BranchLicenseType'),
                                    t_lictypejobobjid,
                                    c_4.branchid);
                            --set the Expiration Date on the Branch License Types based on the new Master
                            api.pkg_columnupdate.setvalue(
                                c_4.branchid,
                                'ExpiringMonth',
                                api.pkg_columnquery.VALUE(t_lictypejobobjid,
                                                          'ExpiringMonth'));
                            api.pkg_columnupdate.setvalue(
                                c_4.branchid,
                                'ExpiringYear',
                                api.pkg_columnquery.VALUE(t_lictypejobobjid,
                                                          'ExpiringYear'));
                        END IF;                           --if t_LicenseJobIds

                        -- Delete the rel from the Master PLT to the Branch LT
                        api.pkg_relationshipupdate.remove(
                            c_4.branchltmasterplt);
                    END LOOP;                                     --Master LTs

                    -- App PLT is Branch of a Master LT
                    FOR b
                        IN (SELECT r6.toobjectid     masterjltid           --,
                                                                --mlt.RelationshipId BranchLTToMasterLT,
                                                                ,
                                   r6.relationshipid branchplttomasterlt
                              FROM api.relationships r6
                             WHERE r6.fromobjectid = c_1.prilictypeobjid
                               AND r6.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'MasterLicenseType')
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM api.relationships r
                                         WHERE r.fromobjectid = r6.toobjectid
                                           AND r.endpointid IN
                                                   (api.pkg_configquery.endpointidforname(
                                                        'j_LicenseType',
                                                        'MasterLicenseType'),
                                                    api.pkg_configquery.endpointidforname(
                                                        'j_LicenseType',
                                                        'MasterBranchLicenseType'))))
                    LOOP
                        -- Get the rel from the Master PLT to the trans from Branch LT and remove it
                        BEGIN
                            SELECT tplt.licensetypejobid
                              INTO t_branchlictyperel
                              FROM query.r_transfromlttoplt tplt
                             WHERE tplt.primarylicensetypeobjectid =
                                   c_1.prilictypeobjid;

                            SELECT br.relationshipid
                              INTO t_relationshipid
                              FROM api.relationships br
                             WHERE br.fromobjectid = b.masterjltid
                               AND br.toobjectid = t_branchlictyperel
                               AND br.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'BranchPrimaryLicenseType');

                            --remove the old branch relationship
                            api.pkg_relationshipupdate.remove(
                                t_relationshipid);
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                NULL;
                        END;

                        -- Remove Branch rels from Branch PLT and Old Branch LT
                        api.pkg_relationshipupdate.remove(
                            b.branchplttomasterlt);
                        api.pkg_columnupdate.setvalue(c_1.prilictypeobjid,
                                                      'IsBranchS',
                                                      'Y');

                        --create the new rel
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'MasterLicenseType'),
                                t_lictypejobobjid,
                                b.masterjltid);
                        --set the expiration on the new Branch LTs to the expiration date of it's Master
                        api.pkg_columnupdate.setvalue(
                            t_lictypejobobjid,
                            'ExpiringMonth',
                            api.pkg_columnquery.VALUE(b.masterjltid,
                                                      'ExpiringMonth'));
                        api.pkg_columnupdate.setvalue(
                            t_lictypejobobjid,
                            'ExpiringYear',
                            api.pkg_columnquery.VALUE(b.masterjltid,
                                                      'ExpiringYear'));
                    END LOOP;

                    -- Master PLT (Trans from Master j_LT) on Transfer app related to Branch PLT
                    FOR m_2
                        IN (SELECT r.toobjectid
                                       pribranchlt,
                                   r.relationshipid
                                       primastertopribranchrelid,
                                   r2.relationshipid
                                       pribranchtojmasterlt
                              FROM api.relationships  r
                                   JOIN api.relationships r2
                                       ON r2.fromobjectid = r.toobjectid
                                      AND r2.endpointid =
                                          api.pkg_configquery.endpointidforname(
                                              'o_PrimaryLicenseType',
                                              'MasterLicenseType')
                             WHERE r.fromobjectid = c_1.prilictypeobjid
                               AND r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'MastertoBranch'))
                    LOOP
                        -- remove rel from Transfer PLT to Branch PLT
                        api.pkg_relationshipupdate.remove(
                            m_2.primastertopribranchrelid);

                        IF t_skip = FALSE THEN
                            --remove the old master relationship
                            api.pkg_relationshipupdate.remove(
                                m_2.pribranchtojmasterlt);

                            --create the new master relationship
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'BranchPrimaryLicenseType'),
                                    t_lictypejobobjid,
                                    m_2.pribranchlt);
                        END IF;
                    END LOOP;

                    -- Branch PLT (Trans from Branch j_LT) on Transfer app related to Master PLT
                    FOR m_3
                        IN (SELECT r.toobjectid     primasterlt,
                                   r.relationshipid pribranchtoprimasterrelid
                              FROM api.relationships r
                             WHERE r.fromobjectid = c_1.prilictypeobjid
                               AND r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'BranchtoMaster')
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM api.relationships r2
                                         WHERE r2.fromobjectid = r.toobjectid
                                           AND r.endpointid IN
                                                   (api.pkg_configquery.endpointidforname(
                                                        'o_PrimaryLicenseType',
                                                        'MasterLicenseType'),
                                                    api.pkg_configquery.endpointidforname(
                                                        'o_PrimaryLicenseType',
                                                        'MastertoBranch'))))
                    LOOP
                        -- Get the rel from the Master PLT to the trans from Branch LT and remove it
                        BEGIN
                            SELECT tplt.licensetypejobid
                              INTO t_branchlictyperel
                              FROM query.r_transfromlttoplt tplt
                             WHERE tplt.primarylicensetypeobjectid =
                                   c_1.prilictypeobjid;

                            SELECT br.relationshipid
                              INTO t_relationshipid
                              FROM api.relationships br
                             WHERE br.fromobjectid = m_3.primasterlt
                               AND br.toobjectid = t_branchlictyperel
                               AND br.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_PrimaryLicenseType',
                                       'MasterPrimaryLicenseType');

                            --remove the old branch relationship
                            api.pkg_relationshipupdate.remove(
                                t_relationshipid);
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                NULL;
                        END;

                        -- remove rel from Transfer PLT to Master PLT
                        api.pkg_relationshipupdate.remove(
                            m_3.pribranchtoprimasterrelid);
                        api.pkg_columnupdate.setvalue(c_1.prilictypeobjid,
                                                      'IsBranchS',
                                                      'Y');
                        --create the new branch relationship
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'MasterBranchLicenseType'),
                                t_lictypejobobjid,
                                m_3.primasterlt);
                    END LOOP;
                /*End Master/Branch*/
                END IF;                -- Master/Branch License Type Candidate
            END LOOP;          -- Primary License Types related to Application
        END;                                          -- Primary License Types

        --Issue any Secondary LTs for existing License Types.
        sitespecific.pkg_issuelicense.issueslt(a_processobjid, a_appobjectid); --not sure if this will work.

        IF t_lastissuelicenseprocess = 'Y' THEN
            FOR plt
                IN (SELECT r.licensetypeobjectid
                               prilictypeobjid,
                           api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                                     'LicenseTypeCode')
                               ltcode
                      FROM query.r_appprimarylicensetype r
                     WHERE r.applicationobjectid = a_appobjectid
                       AND api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                                     'Status') NOT IN
                               (SELECT UPPER(s.description)
                                  FROM api.statuses  s
                                       JOIN api.jobstatuses js
                                           ON js.statusid = s.statusid
                                          AND js.jobtypeid =
                                              api.pkg_configquery.objectdefidforname(
                                                  'j_LicenseType')
                                 WHERE js.statustype IN ('C', 'X')))
            LOOP
                FOR inv
                    IN (SELECT ai.relationshipid   appinvrelid,
                               ai.investigationjobid,
                               iplt.relationshipid applicpltrelid,
                               iplt.primarylicensetypejobid
                          FROM query.r_applicationinvestigation  ai
                               JOIN query.r_investigationprilicensetype iplt
                                   ON iplt.investigationjobid =
                                      ai.investigationjobid
                         WHERE iplt.primarylicensetypejobid =
                               plt.prilictypeobjid)
                LOOP
                    --Move from the Application and Primary License Type
                    api.pkg_relationshipupdate.remove(inv.appinvrelid,
                                                      SYSDATE);
                    api.pkg_relationshipupdate.remove(inv.applicpltrelid,
                                                      SYSDATE);
                    --To the New License and New License Type
                    t_investigationrel   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Investigation',
                                'License'),
                            inv.investigationjobid,
                            t_licobjectid);

                    BEGIN
                        SELECT llt.licensetypejobid
                          INTO t_lictypejobobjid
                          FROM query.r_licenselicensetype llt
                         WHERE llt.licensejobid = t_licobjectid
                           AND api.pkg_columnquery.VALUE(
                                   llt.licensetypejobid,
                                   'LicenseTypeCode') =
                               plt.ltcode;

                        t_applicableltinvrelid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_Investigation',
                                    'LicenseType'),
                                inv.investigationjobid,
                                t_lictypejobobjid);
                    EXCEPTION
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'Investigation Move Fail: Error Relating the Investigation to a License Type. '
                                || SQLERRM);
                    END;
                END LOOP;
            END LOOP;                                              -- PLT Loop

            -- Find all related Investigations that was not related a the Primary License Type
            -- then move it to the new License.
            FOR inv2 IN (SELECT ai.relationshipid, ai.investigationjobid
                           FROM query.r_applicationinvestigation ai
                          WHERE ai.applicationjobid = a_appobjectid)
            LOOP
                -- Move from the Application
                api.pkg_relationshipupdate.remove(inv2.relationshipid,
                                                  SYSDATE);
                -- To the New License
                t_investigationrel   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_Investigation',
                            'License'),
                        inv2.investigationjobid,
                        t_licobjectid);
            END LOOP;
        END IF;

        -- If the License already exists, remove the existing conditions before relating the current ones from the Application
        IF t_licenseexists = 'Y' THEN
            FOR c IN (SELECT r.relationshipid
                        FROM query.r_licensecondition r
                       WHERE r.licensejobid = t_licobjectid
                      UNION
                      SELECT a.relationshipid
                        FROM query.r_licenseadditioncondition a
                       WHERE a.licensejobid = t_licobjectid)
            LOOP
                api.pkg_relationshipupdate.remove(c.relationshipid);
            END LOOP;
        END IF;

        -- Copy Conditions to License
        t_endpointid                  :=
            api.pkg_configquery.endpointidforname('j_License', 'Condition');

        FOR c IN (SELECT *
                    FROM query.r_applicationcondition r
                   WHERE r.applicationjobid = a_appobjectid)
        LOOP
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_licobjectid,
                                               c.conditionobjectid);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'DetailsCopied',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionText',
                                          c.conditiontext);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionCode',
                                          c.conditioncode);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionRelCount',
                                          c.conditionrelcount);
            api.pkg_columnupdate.setvalue(t_relationshipid, 'Sort', c.sort);
        END LOOP;

        -- Copy Additional Conditions to License
        t_endpointid                  :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'AdditCondition');
        t_objectdefid                 :=
            api.pkg_configquery.objectdefidforname('o_AdditionalCondition');

        FOR x
            IN (SELECT ac.objectid, ac.sort2, ac.conditiontext
                  FROM query.r_applicationadditioncondition  r
                       JOIN query.o_additionalcondition ac
                           ON ac.objectid = r.additionalconditionobjectid
                 WHERE r.applicationjobid = a_appobjectid)
        LOOP
            t_newobjectid   := api.pkg_objectupdate.new(t_objectdefid);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'ConditionText',
                                          x.conditiontext);
            api.pkg_columnupdate.setvalue(t_newobjectid, 'Sort2', x.sort2);
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_licobjectid,
                                               t_newobjectid);
        END LOOP;
    END issuetransferlicense;

    ----------------------------------------------------------------------------------------------------
    -- IssueTransferToActiveLicense() -- PUBLIC
    -- Issue a Transfer to an Active Licesene
    ----------------------------------------------------------------------------------------------------
    PROCEDURE issuetransfertoactivelicense(
        a_appobjectid   udt_id,
        a_processobjid  udt_id DEFAULT NULL)
    IS
        t_cnt           INTEGER;
        t_lestodelete   udt_objectlist;
    BEGIN
        t_appdefid   :=
            api.pkg_configquery.objectdefidforname('j_Application');
        t_dbadefid   := api.pkg_configquery.objectdefidforname('o_DBANames');
        t_appdbanamesreldefid   :=
            api.pkg_configquery.objectdefidforname('r_ApplicationDBANames');
        t_licdbanamesreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseDBANames');
        t_applegalentityappepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Applicant');
        t_applegalentityosmepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'OnSaleManager');
        t_applegalentityflepid        :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'FoodLesseeApp');   -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
        t_applegalentityp12epid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'P12Applicant');
        t_applegalentityprip12id   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'PrimaryP12Applicant');
        t_lastissuelicenseprocess   :=
            api.pkg_columnquery.VALUE(a_processobjid, 'IsIssueAllLTs');
        t_liclelicenseeepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'LicenseeLegalEntity');
        t_licleosmepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'OSMLegalEntity');
        t_licleflepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'FoodLesseeLic');   --05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
        t_liclep12epid   :=
            api.pkg_configquery.endpointidforname('j_License', 'P12Licensee');
        t_licleprip12epid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'PrimaryP12Licensee');
        t_licdefid   :=
            api.pkg_configquery.objectdefidforname('j_License');
        t_lictypedefid   :=
            api.pkg_configquery.objectdefidforname('j_LicenseType');
        t_priltltcatprimaryreldef   :=
            api.pkg_configquery.objectdefidforname('r_PriLTLTCatPrimary');
        t_priltltcatsecondaryreldef   :=
            api.pkg_configquery.objectdefidforname('r_PriLTLTCatSecondary');
        t_appprilictypereldef   :=
            api.pkg_configquery.objectdefidforname('r_AppPrimaryLicenseType');
        t_liclelicenseereldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseLegalEntityLicensee');
        t_licleosmreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseLegalEntityOSM');
        t_liclictypereldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseLicenseType');
        t_lictypltcatprireldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseTypeLTCatPrimary');
        t_lictypltcatsecreldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseTypeLTCatSecondary');
        t_lictxfrfromreldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_ApplicationLicenseTransfer');
        t_psltendpointid   :=
            api.pkg_configquery.endpointidforname(
                'o_PendingSecondaryLicenseType',
                'PendLicTypeCatSecondary');
        t_pltendpointid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'PendSecLicType');

        -- grab details from application.
        SELECT a.applicationtype,
               a.licensenumber,
               a.licensebeingchanged,
               a.licensetypeexchange,
               a.membershiptransfer,
               a.stocktransfer,
               a.externalfilenum,
               a.istemporarymailingaddress,
               a.conda,
               a.ispriorityapplication,
               a.felony,
               a.violation
          INTO t_applicationtype,
               t_licensenumber,
               t_licensebeingchanged,
               t_licensetypeexchange,
               t_membershiptransfer,
               t_stocktransfer,
               t_externalfilenum,
               t_tempaddr,
               t_governmentowned,
               t_priorityapplication,
               t_felony,
               t_violation
          FROM query.j_application a
         WHERE a.jobid = a_appobjectid;

        BEGIN
            -- Get the objectid of the active license being transfered to
            SELECT c.licensetransferredtoobjectid
              INTO t_chnglicobjid
              FROM query.r_applicationlicensetransferto c
             WHERE c.apptransferredfromobjectid = a_appobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       ' ERROR. Could not identify Active License being transfered to.'
                    || SQLERRM);
        END;

        -- Start of tasks performed regardless of Application Change Type.

        BEGIN  --copy Felony and Violation details from Application to License
            api.pkg_columnupdate.setvalue(t_chnglicobjid, 'Felony', t_felony);
            api.pkg_columnupdate.setvalue(t_chnglicobjid,
                                          'Violation',
                                          t_violation);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'ERROR copying Felony and Violation details. ' || SQLERRM);
        END;

        BEGIN                  --remove existing Premises Address relationship
            SELECT r.relationshipid
              INTO t_premaddrobjectid
              FROM query.r_licenseaddrpremises r
             WHERE r.licensejobid = t_chnglicobjid;

            api.pkg_relationshipupdate.remove(t_premaddrobjectid, SYSDATE);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;             --if there is no premises address do nothing
        END;

        BEGIN
            --Always Copy the Premises Address from the Application to the License
            SELECT r.addressobjectid                              --ToObjectId
              INTO t_premaddrobjectid
              FROM query.r_applicationpremaddr r
             WHERE r.applicationjobid = a_appobjectid;

            -- Relate Premises Address object to Application
            t_newrelobjectid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('j_License',
                                                          'Premises'),
                    t_chnglicobjid,
                    t_premaddrobjectid);
        EXCEPTION
            WHEN OTHERS THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'ERROR with Existing Premises Address. ' || SQLERRM);
        END;

        BEGIN                               -- Mailing Address for the license
            SELECT r.addressobjectid,
                   api.pkg_columnquery.VALUE(r.applicationjobid,
                                             'IsTemporaryMailingAddress')
              INTO t_mailaddrobjectid, t_tempaddr
              FROM query.r_applicationmailaddr r
             WHERE r.applicationjobid = a_appobjectid;

            SELECT r.relationshipid, r.maobjectid
              INTO t_licmailaddrrelid, t_licmailaddrobjectid
              FROM query.r_licenseaddrmailing r
             WHERE r.licensejobid = t_chnglicobjid;

            --      if t_tempaddr <> 'Y' then
            -- Remove current mailing address, if exists, and replace with mail addr from app.
            -- if not a temporary address and this is not a P12 application then create the Mailing Address Rel
            IF t_tempaddr <> 'Y'
           AND p12applicantcount(a_appobjectid) = 0 THEN
                IF t_licmailaddrobjectid <> t_mailaddrobjectid
                OR (t_licmailaddrobjectid IS NULL
                AND t_mailaddrobjectid IS NOT NULL)
                OR (t_mailaddrobjectid IS NULL
                AND t_licmailaddrobjectid IS NOT NULL) THEN
                    api.pkg_columnupdate.setvalue(t_licmailaddrrelid,
                                                  'RunProcedureOnDeletion',
                                                  'Y');
                    api.pkg_relationshipupdate.remove(t_licmailaddrrelid);
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'MailingAddress'),
                            t_chnglicobjid,
                            t_mailaddrobjectid);
                END IF;
            END IF;                          -- Temporary Mailing Address test
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_newrelobjectid   := NULL;
        END;

 -- Email Address Added by Pawan WO 20669 for transfer apps --3/30/2020
 --Remove existing Email License relationship
    BEGIN
            SELECT r.relationshipid
              INTO t_emailaddrobjectid
              FROM query.r_EmailsLicense r
             WHERE r.licensejobid = t_chnglicobjid;

            api.pkg_relationshipupdate.remove(t_emailaddrobjectid, SYSDATE);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;             --if there is no email address do nothing
        END;

        BEGIN
            --Always Copy the Email from the Application to the License
             SELECT r.EmailObjectId                              --ToObjectId
              INTO t_emailaddrobjectid
              FROM query.r_EmailsApplication r
             WHERE r.applicationjobid = a_appobjectid;

            -- Relate Email object to Application
            t_newrelobjectid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('j_License',
                                                          'LicenseEmail'),
                    t_chnglicobjid,
                     t_emailaddrobjectid);

               EXCEPTION
             WHEN NO_DATA_FOUND THEN
                    t_newrelobjectid   := NULL;
        END; --End WO 20669 Added by Pawan for Price posting email Transfer License

        -- Find the current revision of Conditions Document ABC-172 (if exists), and relate to License
        BEGIN
            t_abc172docid := GetConditionalDoc(a_appobjectid);
            IF t_abc172docid IS NOT NULL THEN
                t_endpointid   :=
                    api.pkg_configquery.endpointidforname('j_License',
                                                          'ABCWordDocument');
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_chnglicobjid,
                                                   t_abc172docid);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;          -- Conditions document is option; just move on.
        END;

        BEGIN      -- Update/Add DBAs on the License to match Application info
            FOR c_dbaapp IN (SELECT d.dba      dbanameapp, -- DBAs on the Application
                                    d.active,
                                    d.objectid dbaappobjid,
                                    d.primarydba
                               FROM query.o_dbanames  d
                                    JOIN api.relationships r
                                        ON r.toobjectid = d.objectid
                                       AND r.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'j_Application',
                                               'DBANames')
                              WHERE r.fromobjectid = a_appobjectid)
            LOOP
                BEGIN      -- Does this DBA from the App exist on the license?
                    SELECT d.objectid
                      INTO t_dbalicobjid
                      FROM query.o_dbanames  d
                           JOIN api.relationships r
                               ON r.toobjectid = d.objectid
                              AND r.endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'j_License',
                                      'DBANames')
                     WHERE r.fromobjectid = t_chnglicobjid
                       AND d.dba = c_dbaapp.dbanameapp;

                    api.pkg_columnupdate.setvalue(t_dbalicobjid,
                                                  'Active',
                                                  c_dbaapp.active);
                    api.pkg_columnupdate.setvalue(t_dbalicobjid,
                                                  'PrimaryDBA',
                                                  c_dbaapp.primarydba);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_dbanewobjid   :=
                            api.pkg_objectupdate.new(t_dbadefid);

                        pkg_copy.copystoredobjectdetails(
                            c_dbaapp.dbaappobjid,
                            t_dbanewobjid);

                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_License',
                                    'DBANames'),
                                t_chnglicobjid,
                                t_dbanewobjid);
                END;
            END LOOP;                                   -- DBAs on Application
        END;

        BEGIN                -- find DBAs on the License which are not on App.
            FOR c_dbalic IN (SELECT d.objectid dbaobjidlic, d.dba
                               FROM query.o_dbanames  d
                                    JOIN api.relationships r
                                        ON r.toobjectid = d.objectid
                                       AND r.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'j_License',
                                               'DBANames')
                              WHERE r.fromobjectid = t_chnglicobjid)
            LOOP
                BEGIN
                    SELECT d.dba
                      INTO t_dbanameapp
                      FROM query.o_dbanames  d
                           JOIN api.relationships r
                               ON r.toobjectid = d.objectid
                              AND endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'j_Application',
                                      'DBANames')
                     WHERE r.fromobjectid = a_appobjectid
                       AND d.dba = c_dbalic.dba;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- Update the details of this existing DBA to match app.
                        api.pkg_columnupdate.setvalue(c_dbalic.dbaobjidlic,
                                                      'Active',
                                                      'N');
                        api.pkg_columnupdate.setvalue(c_dbalic.dbaobjidlic,
                                                      'PrimaryDBA',
                                                      'N');
                END;
            END LOOP;           -- DBAs on License that are not on Application
        EXCEPTION
            WHEN OTHERS THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    ' ERROR evaluating existing DBAs on License.' || SQLERRM);
        END;   --End of tasks performed regardless of Application Change Type.

        -- grab all current LEs on the License
        FOR c_lelic
            IN (SELECT c.relationshipid relationshipidlicle,
                       c.toobjectid     leobjectid,
                       c.endpointid     endpointid
                  FROM api.relationships c
                 WHERE c.endpointid IN (t_liclelicenseeepid,
                                        t_licleosmepid,
                                        t_licleflepid,
                                        t_liclep12epid,
                                        t_licleprip12epid)
                   AND c.fromobjectid = t_chnglicobjid)
        LOOP
            --Remove Legal Entity's Children
            IF c_lelic.endpointid NOT IN (t_liclep12epid, t_licleprip12epid) THEN
                t_lestodelete   := api.udt_objectlist();
                sitespecific.pkg_legalentity.getlegalentitychildren(
                    c_lelic.leobjectid,
                    t_lestodelete);

                FOR c_2 IN 1 .. t_lestodelete.COUNT
                LOOP
                    api.pkg_objectupdate.remove(t_lestodelete(c_2).objectid);
                END LOOP;

                -- Remove Legal Entity object
                api.pkg_objectupdate.remove(c_lelic.leobjectid);
            ELSE
                api.pkg_relationshipupdate.remove(
                    c_lelic.relationshipidlicle);
            END IF;
        END LOOP;                       -- grab all current LEs on the License

        BEGIN                -- Add Legal Entities from Application to License
            FOR c_le
                IN (SELECT toobjectid, endpointid
                      FROM api.relationships
                     WHERE fromobjectid = a_appobjectid
                       AND endpointid IN
                               (t_applegalentityappepid,
                                t_applegalentityosmepid,
                                t_applegalentityflepid,
                                t_applegalentityp12epid))
            LOOP
                IF c_le.endpointid NOT IN
                       (t_applegalentityp12epid, t_applegalentityprip12id) THEN -- Copy the Legal Entity associated with the Application
                    t_legalentityobjid   :=
                        pkg_legalentity.legalentitycopy(c_le.toobjectid);
                ELSE -- the existing P12 legal entity will be related to the license.
                    t_legalentityobjid   := c_le.toobjectid;
                END IF;

                -- Get the endpoint for the rel from license to le
                CASE
                    WHEN c_le.endpointid = t_applegalentityappepid THEN
                        t_createrelendpointid   := t_liclelicenseeepid;
                    WHEN c_le.endpointid = t_applegalentityosmepid THEN
                        t_createrelendpointid   := t_licleosmepid; 
                    WHEN c_le.endpointid = t_applegalentityflepid THEN
                        t_createrelendpointid   := t_licleflepid;
                    WHEN c_le.endpointid = t_applegalentityp12epid THEN
                        t_createrelendpointid   := t_liclep12epid;
                    WHEN c_le.endpointid = t_applegalentityprip12id --When looking at the Primary P12 Relationship Copy the rel
                                                                    THEN
                        t_createrelendpointid   := t_licleprip12epid;
                END CASE;

                -- Relate the Legal Entity to the License
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_createrelendpointid,
                                                   t_chnglicobjid,
                                                   t_legalentityobjid);
            END LOOP;                         -- Legal Entities on Application
        END;                                                 -- Legal Entities

        -- For Change applications with type License Type Exchange.
        -- Add additional License Type Job to License, per Primary License Type on Application.
        -- Update existing License Type Job to add or drop Secondary License Type, per Pri Lic Type on Application
        -- Cancel License Type Job which doesn't have corresponding Primary License Type on Application
        -- Remove secondaries off license which are not found on application.
        -- For every PLT move the related investigation to the License job.
        -- All License Types on License will have "IncludeInBatch" flag set to "Y".

        -- Get the ready to issue date from the Application
        t_readytoissuedate   :=
            api.pkg_columnquery.datevalue(a_appobjectid, 'ReadyToIssueDate');

        -- Grab Primary License Types (PLT) associated with the Application
        FOR c_1
            IN (SELECT r1.toobjectid
                           prilictypeobjid,
                       r2.toobjectid
                           ltcobjid,
                       api.pkg_columnquery.VALUE(r2.toobjectid,
                                                 'LicenseTypeCode')
                           licensetypecode,
                       api.pkg_columnquery.VALUE(r1.toobjectid,
                                                 'TypeofIssuance')
                           typeofissuance,
                       api.pkg_columnquery.VALUE(r1.toobjectid,
                                                 'BranchApplies')
                           branchapplies
                  FROM api.relationships  r1
                       JOIN api.relationships ilt
                           ON ilt.toobjectid = r1.toobjectid
                          AND ilt.fromobjectid = a_processobjid
                       JOIN api.relationships r2
                           ON r2.fromobjectid = r1.toobjectid
                          AND r2.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'o_PrimaryLicenseType',
                                  'LicTypeCatPrimary')
                 WHERE r1.fromobjectid = a_appobjectid
                   AND r1.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_Application',
                           'PrimaryLicenseType')
                   AND ilt.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'p_IssueLicense',
                           'PrimaryLicenseType')
                   AND (api.pkg_columnquery.VALUE(ilt.relationshipid,
                                                  'Issue') =
                        'Y'
                     OR (api.pkg_columnquery.VALUE(ilt.fromobjectid,
                                                   'IssueAllLicenseTypes') =
                         'Y'
                     AND api.pkg_columnquery.VALUE(r1.toobjectid, 'Issued') =
                         'N'))
                   AND api.pkg_columnquery.VALUE(r1.toobjectid, 'Status') NOT IN
                           (SELECT UPPER(s.description)
                              FROM api.statuses  s
                                   JOIN api.jobstatuses js
                                       ON js.statusid = s.statusid
                                      AND js.jobtypeid =
                                          api.pkg_configquery.objectdefidforname(
                                              'j_LicenseType')
                             WHERE js.statustype IN ('C', 'X')))
        LOOP
            -- Set the Issued Boolean when the PLT is included in the Issue process.
            api.pkg_columnupdate.setvalue(c_1.prilictypeobjid, 'Issued', 'Y');

            IF api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'Status') =
               'PENDING' THEN
                api.pkg_columnupdate.setvalue(c_1.prilictypeobjid,
                                              'Status',
                                              'ISSUED');
            END IF;

            BEGIN --Is this Primary License Type already on the License as a Primary?  If not, add a License Type Job to License
                SELECT r1.toobjectid, r1.fromobjectid, r2.toobjectid
                  INTO t_liclictypcatpriobjid,
                       t_licpltobjid,
                       t_lictypejobobjid
                  FROM api.relationships  r1
                       JOIN api.relationships r2
                           ON r2.toobjectid = r1.fromobjectid
                          AND r2.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'j_License',
                                  'LicenseType')
                 WHERE r2.fromobjectid = t_chnglicobjid
                   AND r1.toobjectid = c_1.ltcobjid
                   AND r1.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_LicenseType',
                           'LicTypeCatPrimary');

                api.pkg_errors.raiseerror(
                    -20000,
                    'LT category already exists on License being transfered to.');
            /*\* -- If flow gets here, License Type Category - Primary already exists on License side
             --set details on the j_LT based on the values from the o_PLT
             --first set this detail to 'Y' to allow for the Gallonage Range to be set to null prior to the Branch LT rel being set
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'IsChangeProcRunning', 'Y');
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'DesignatedExpirationDate', api.pkg_columnquery.value(c_1.prilictypeobjid, 'DesignatedExpirationDate'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'COND1C', api.pkg_columnquery.value(c_1.prilictypeobjid, 'COND1C'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'COND8', api.pkg_columnquery.value(c_1.prilictypeobjid, 'COND8'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'COND9', api.pkg_columnquery.value(c_1.prilictypeobjid, 'COND9'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'COND2', api.pkg_columnquery.value(c_1.prilictypeobjid, 'COND2'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'CONDA', api.pkg_columnquery.value(c_1.prilictypeobjid, 'CONDA'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'CONDD', api.pkg_columnquery.value(c_1.prilictypeobjid, 'CONDD'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'CONDI', api.pkg_columnquery.value(c_1.prilictypeobjid, 'CONDI'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'COND5', api.pkg_columnquery.value(c_1.prilictypeobjid, 'COND5'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'ConditionEndDate', api.pkg_columnquery.value(c_1.prilictypeobjid, 'ConditionEndDate'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'BondedWinery', api.pkg_columnquery.value(c_1.prilictypeobjid, 'BondedWinery'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'GallonageRange', api.pkg_columnquery.value(c_1.prilictypeobjid, 'GallonageRange'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'AdditionalMillionGallons', api.pkg_columnquery.value(c_1.prilictypeobjid, 'AdditionalMillionGallons'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'NumberOfMonthsLicensed', api.pkg_columnquery.value(c_1.prilictypeobjid, 'NumberOfMonthsLicensed'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'SeasonStartMonth', api.pkg_columnquery.value(c_1.prilictypeobjid, 'SeasonStartMonth'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'PrimaryCount', api.pkg_columnquery.value(c_1.prilictypeobjid, 'PrimaryCount'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'StatusDate', api.pkg_columnquery.Value(c_1.prilictypeobjid, 'StatusDate'));
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'TypeofIssuance', c_1.typeofissuance);

             -- Set flags on LT
             api.pkg_columnupdate.SetValue(t_LicTypeJobObjId, 'IncludeInChangeAppBatch', 'Y');
             api.pkg_columnupdate.SetValue(t_LicTypeJobObjId, 'ReadyToIssueDate', t_ReadytoIssueDate);
             api.pkg_columnupdate.SetValue(t_LictypeJobObjId, 'TypeofIssuance', c_1.typeofissuance);
             -- Set the batch flags
             pkg_BatchType.SetBatchFlags(a_LicTypeJobId => t_LicTypeJobObjId,
                                         a_IncludeInProduceLicenseBatch => 'Y',
                                         a_IncludeInDailyBatch => 'Y');

     \********************************************Testing***********************************************************************\
                for b_1 in (select ToObjectId MasterLTObjId,
                                  RelationshipId
                           from api.relationships
                           where FromObjectId = c_1.prilictypeobjid
                           and EndPointId = api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'MasterLicenseType')) loop
                 api.pkg_RelationshipUpdate.Remove(b_1.RelationshipId);
               end loop;

               --get the relationship of when the issuing PLT is related to a Master PLT  Copy it over and remove the previous rel from the original Branch PLT to the Master PLT
               for b_2 in (select r.toobjectid MasterPLT,
                                  r.relationshipid ToMasterRelId
                           from api.relationships r
                           where r.fromobjectid = c_1.prilictypeobjid
                           and r.endpointid = api.pkg_configquery.endpointidforname('o_PrimaryLicenseType', 'BranchtoMaster'))loop
                 api.pkg_relationshipupdate.Remove(b_2.tomasterrelid);
               end loop; --to Master Primary License Type

               --get the relationship of when the issuing PLT is related to a Branch PLT  Copy it over and remove the previous rel from the original Master PLT to the Branch PLT
               for b_3 in (select r.toobjectid BranchPLT,
                                  r.RelationshipId
                           from api.relationships r
                           where r.fromobjectid = c_1.prilictypeobjid
                           and r.endpointid = api.pkg_configquery.endpointidforname('o_PrimaryLicenseType', 'MastertoBranch')) loop
                 api.pkg_relationshipupdate.Remove(b_3.RelationshipId);
               end loop; --to Master Primary License Type

               ------+++++ PLT is a Master of a Branch License Type
               for b_4 in (select ToObjectId MasterLTObjId,
                                  RelationshipId
                           from api.relationships
                           where FromObjectId = c_1.prilictypeobjid
                           and EndPointId = api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'MasterPrimaryLicenseType')) loop
                 api.Pkg_RelationshipUpdate.Remove(b_4.RelationshipId);
               end loop;
     \********************************************Testing************************************************************************\

             -- Now find License Type Category - Secondary from Primary License Type on Application
             -- Objective: Add any new Secondary License Types from the App to the License
             for c_2 in (select slt.ToObjectId LTCSecObjId,
                                slt.RelationshipId AppRelPLTSecLTC,
                                islt.RelationshipId IssSecCatRelId
                         from api.relationships slt
                         join query.r_IssueLicenseLTCatSecondary islt on islt.MasterLTObjectId = slt.fromObjectId
                                                                      and islt.IssueLicenseProcessId = a_ProcessObjId
                                                                      and islt.LicenseTypeCategoryObjectId = slt.toObjectId
                         where slt.FromObjectId = c_1.PriLicTypeObjId
                         and slt.EndpointId = api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'LicTypeCatSecondary')
                         and (islt.Issue = 'Y'
                         or api.pkg_columnquery.value(islt.IssueLicenseProcessId,'IssueAllLicenseTypes') = 'Y')
                         and api.pkg_columnquery.value(slt.RelationshipId, 'SStatus') not in (select upper(s.Description)
                                                                                              from api.statuses s
                                                                                              join api.jobstatuses js on js.StatusId = s.StatusId
                                                                                              and js.JobTypeId = api.pkg_configquery.ObjectDefIdForName('j_LicenseType')
                                                                                              where js.StatusType in ('C', 'X'))) loop
               -- Set the Issued Boolean when the SLT is included in the Issue process.
               api.pkg_columnupdate.SetValue(c_2.apprelpltsecltc, 'Issued', 'Y');
               api.pkg_columnupdate.SetValue(c_2.Issseccatrelid, 'Issued', 'Y');
               if api.pkg_columnquery.Value(c_2.apprelpltsecltc, 'SStatus') = 'PENDING' then
                 api.pkg_columnupdate.SetValue(c_2.apprelpltsecltc,'SStatus','ISSUED');
                 api.pkg_columnupdate.setvalue(c_2.Issseccatrelid, 'Status', 'ISSUED');
               end if;

               -- Is this Secondary Already on the License?  If yes, then only update the Count detail.
               \*BEGIN
                 select r1.ToObjectId,
                        r1.FromObjectId,
                        r1.RelationshipId-- r1.EndPointId
                 into t_LicLicTypCatPriObjid,
                      t_LicPLTObjId,
                      t_LicRelLTSecLTC
                 from api.relationships r1
                 join api.relationships r2 on r2.ToObjectId = r1.FromObjectId
                                           and r2.EndPointId =  api.pkg_configquery.EndPointIdForName('j_License', 'LicenseType')
                 where r2.FromObjectId = t_ChngLicObjId
                 and r1.ToObjectId = c_2.LTCSecObjId
                 and r1.EndPointId = api.pkg_configquery.EndPointIdForName('j_LicenseType', 'LicTypeCatSecondary');

                 pkg_copy.CopyStoredObjectDetails(c_2.AppRelPLTSecLTC, t_LicRelLTSecLTC);
                 api.pkg_columnupdate.setvalue(t_LicRelLTSecLTC, 'TypeOfIssuance', c_1.typeofissuance);
                 api.pkg_columnupdate.SetValue(t_LicRelLTSecLTC, 'IncludeInChangeAppBatch', 'Y');
                 api.pkg_columnupdate.SetValue(t_LicRelLTSecLTC, 'ReadyToIssueDate', t_ReadytoIssueDate);
                 -- Set the batch flags
                 pkg_BatchType.SetBatchFlags(a_LicTypeJobId => t_LicRelLTSecLTC,
                                             a_IncludeInProduceLicenseBatch => 'Y',
                                             a_IncludeInDailyBatch => 'Y');
               EXCEPTION WHEN NO_DATA_FOUND THEN*\
                 -- Relate this Secondary License Type to the Existing Primary License Type on the License
                 t_NewRelObjectId := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName('j_LicenseType', 'LicTypeCatSecondary'), t_LicPLTObjId, c_2.LTCSecObjId);
                 -- Set the Status Date and Status on the New License Type
                 api.pkg_columnupdate.SetValue(t_NewRelObjectId, 'StatusDate', sysdate);
                 -- Copy License Type Count for the Secondary License Type
                 pkg_copy.CopyStoredObjectDetails(c_2.apprelpltsecltc, t_NewRelObjectId);
                 -- Set the Status Date and Status on the New License Type
                 api.pkg_columnupdate.SetValue(t_NewRelObjectId, 'Status', 'PENDING');
                 -- Set the Ready To Issue Date --HotFix22 Part One
                 api.pkg_columnupdate.setvalue(t_NewRelObjectId, 'ReadyToIssueDate', t_ReadytoIssueDate);
                 -- Set the Type Of Issuance for the secondary types. HotFix22 Part One
                 api.pkg_columnupdate.setvalue(t_NewRelObjectId, 'TypeOfIssuance', 'DOR');
                 api.pkg_columnupdate.SetValue(t_NewRelObjectId, 'IncludeInChangeAppBatch', 'Y');
                 -- Set the Batch Flags
                 sitespecific.pkg_batchtype.SetBatchFlags(a_LicTypeJobId => t_NewRelObjectId,
                                                          a_IncludeInProduceLicenseBatch => 'Y',
                                                          a_IncludeInDailyBatch => 'Y');
              \* WHEN OTHERS THEN
                 api.pkg_Errors.RaiseError(-20000, 'ERROR relating Secondary LT with Existing Primary License Type:'|| c_1.licensetypecode || SQLERRM);
               END;*\
             end loop; -- c_2  Secondaries on the Application being added to existing Primary on License

             -- Maintian Dups for the Secondary Relationships
             api.pkg_columnupdate.setvalue(t_LicPLTObjId, 'dup_IncludeInProduceLicBatchSe', 'Y');

             -- For existing License Types set the batch flags if the status is in an Initial or Intermediate status type
             select count(*)
             into t_cnt
             from api.processtypes apt
             join api.processoutcomes apo on apo.ProcessTypeId = apt.ProcessTypeId
             join api.statuschanges astc on astc.ProcessOutcomeId = apo.ProcessOutcomeId
             join api.statuses as1 on as1.StatusId = astc.FromStatusId
             join api.jobstatuses ajs on ajs.StatusId = as1.StatusId and ajs.JobTypeId = apo.JobTypeId
             where apt.processtypeid = api.pkg_configquery.objectdefidforname('p_IssueLicenseType')
             and apo.jobtypeid = (select jobtypeid from api.jobs where jobid = t_LicPLTObjId)
             and as1.Description = api.pkg_columnquery.value(t_LicPLTObjId,'StatusDescription')
             and ajs.statustype in ('I','O');

             if (t_cnt > 0) then
               pkg_BatchType.SetBatchFlags(a_LicTypeJobId => t_LicPLTObjId, a_IncludeInProduceLicenseBatch => 'Y', a_IncludeInDailyBatch => 'Y');
             end if;

             BEGIN
               --update the existing License Types for the Branch/Master relationships according to the o_PLT
               --for the o_PLT that are Branch LTs (with Master j_LT) delete the previous rels from Branch j_LT to Master j_LT
               for b_1 in (select j.jobid,
                                  r.toobjectid MasterLTJobId,
                                  r.RelationshipId BranjLTtoMastLTRelId
                           from api.jobs j
                           left outer join api.relationships r on r.fromobjectid =  j.jobid
                           and r.endpointid = api.pkg_configquery.EndPointIdForName('j_LicenseType', 'MasterLicenseType')
                           left outer join api.relationships r1 on r1.fromobjectid =  j.jobid
                           and r1.endpointid = api.pkg_configquery.EndPointIdForName('j_LicenseType', 'MasterBranchLicenseType')
                           where j.jobid = t_LicPLTObjId) loop
                 select r1.toobjectid,
                        r1.RelationshipId,
                        r1.EndpointId
                 into t_MasterLTObjId,
                      t_RelationshipId,
                      t_EndPointId
                 from api.relationships r1
                 where r1.FromObjectId = c_1.Prilictypeobjid
                 and (r1.EndPointId = api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'MasterLicenseType')
                 or r1.EndPointId = api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'BranchtoMaster'));

                 --Delete the relationship so that the new ones created are the most recent and updated
                 if b_1.branjlttomastltrelid is not null then
                   api.pkg_relationshipupdate.remove(b_1.branjlttomastltrelid);
                 else
                   null;
                 end if;

                 --create new rels from the NEW Branch j_LT to the Master j_LT that the Branch o_PLT is related to
                 if t_MasterLTObjId is not null then
                   -- Remove the rel from the PLT to the Master LT
                   api.pkg_RelationshipUpdate.Remove(t_RelationshipId);
                   api.pkg_ColumnUpdate.SetValue(c_1.PriLicTypeObjId,'IsBranchS','Y');
                   -- If the PLT is the Branch of a j_LT, then update the Change LT to this rel
                   if t_EndpointId = api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'MasterLicenseType') then
                     t_NewRelObjectId := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName('j_LicenseType','MasterLicenseType'), t_LicPLTObjId, t_MasterLTObjId);
                     --and set the expirationdate of the new LT to the expiration date of it's Master
                     api.pkg_columnupdate.setvalue(t_LicPLTObjId, 'ExpiringMonth', api.pkg_columnquery.value(t_MasterLTObjId, 'ExpiringMonth'));
                     api.pkg_columnupdate.setvalue(t_LicPLTObjId, 'ExpiringYear', api.pkg_columnquery.value(t_MasterLTObjId, 'ExpiringYear'));
                     -- If the PLT is a Branch of a o_PLT, then update the Change LT to this rel
                   elsif t_EndpointId = api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'BranchtoMaster') then
                     t_NewRelObjectId := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName('j_LicenseType','MasterBranchLicenseType'), t_LicPLTObjId, t_MasterLTObjId);
                   end if;
                 end if;

                 t_RelationshipId := b_1.branjlttomastltrelid;
               end loop;
             EXCEPTION WHEN NO_DATA_FOUND THEN --go ahead and delete the old relationship
               if t_RelationshipId is not null then
                 --Delete the relationship so that the new ones created are the most recent and updated
                 api.pkg_relationshipupdate.remove(t_RelationshipId);
               else null;
               end if;
             END;

             --Set the boolean back to 'N' so that the Raise Error condition will be checked again
             api.pkg_columnupdate.SetValue(t_LicPLTObjId, 'IsChangeProcRunning', 'N');*/
            EXCEPTION
                WHEN NO_DATA_FOUND THEN  -- Add this Primary LT Cat to License
                    -- Create License Type Job, relate to Lic Type Cat
                    t_lictypejobobjid   :=
                        api.pkg_objectupdate.new(t_lictypedefid);
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_LicenseType',
                                'LicTypeCatPrimary'),
                            t_lictypejobobjid,
                            c_1.ltcobjid);

                    -- If this PLT is transferred, log this to the License Transfers table
                    IF api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                                 'IsTransferred') =
                       'Y' THEN
                        -- Log the Transfer with the License Transfers object
                        pkg_issuelicense.loglicensetransfer(
                            t_lictypejobobjid,
                            c_1.licensetypecode,
                            t_licensenumber,
                            c_1.prilictypeobjid,
                            a_appobjectid);
                    END IF;

                    -- Copy License Type details from App
                    pkg_copy.copystoredobjectdetails(c_1.prilictypeobjid,
                                                     t_lictypejobobjid);
                    api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                                  'ReadyToIssueDate',
                                                  t_readytoissuedate);
                    api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                                  'TypeofIssuance',
                                                  c_1.typeofissuance);
                    api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                                  'IncludeInChangeAppBatch',
                                                  'Y');
                    -- For New Primary LT set the batch flags
                    pkg_batchtype.setbatchflags(
                        a_lictypejobid => t_lictypejobobjid,
                        a_includeinproducelicensebatch => 'Y',
                        a_includeindailybatch => 'Y');
                    -- Relate newly created License Type Job to License
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'LicenseType'),
                            t_chnglicobjid,
                            t_lictypejobobjid);
                    -- Set Expiring Month and Year
                    pkg_issuelicense.setexpmonthyear(a_appobjectid,
                                                     SYSDATE,
                                                     c_1.prilictypeobjid,
                                                     t_lictypejobobjid);

                    -- Master/Branch License Type Candidate
                    IF c_1.branchapplies = 'Y' THEN
                        FOR b_1
                            IN (SELECT toobjectid masterltobjid,
                                       relationshipid
                                  FROM api.relationships
                                 WHERE fromobjectid = c_1.prilictypeobjid
                                   AND endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_PrimaryLicenseType',
                                           'MasterLicenseType'))
                        LOOP
                            -- Remove rel from PLT to LT
                            api.pkg_columnupdate.setvalue(
                                c_1.prilictypeobjid,
                                'IsBranchS',
                                'Y');
                            -- Relate the Branch to the Master
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'MasterLicenseType'),
                                    t_lictypejobobjid,
                                    b_1.masterltobjid);
                            --Set the ExpirationDate of the new Branch LT to the ExpirationDate of it's Master LT
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringMonth',
                                api.pkg_columnquery.VALUE(b_1.masterltobjid,
                                                          'ExpiringMonth'));
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringYear',
                                api.pkg_columnquery.VALUE(b_1.masterltobjid,
                                                          'ExpiringYear'));
                            api.pkg_relationshipupdate.remove(
                                b_1.relationshipid);
                        END LOOP;

                        --get the relationship of when the issuing PLT is related to a Master PLT  Copy it over and remove the previous rel from the original Branch PLT to the Master PLT
                        FOR b_2
                            IN (SELECT r.toobjectid     masterplt,
                                       r.relationshipid tomasterrelid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = c_1.prilictypeobjid
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_PrimaryLicenseType',
                                           'BranchtoMaster'))
                        LOOP
                            --Create the new relationship from the Branch j_LicenseType to the Master PLT
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'MasterBranchLicenseType'),
                                    t_lictypejobobjid,
                                    b_2.masterplt);
                            --remove the relationship from the previous Branch PLT to the Master PLT
                            api.pkg_relationshipupdate.remove(
                                b_2.tomasterrelid);
                            api.pkg_columnupdate.setvalue(
                                c_1.prilictypeobjid,
                                'IsBranchS',
                                'Y');
                        END LOOP;             --to Master Primary License Type

                        --get the relationship of when the issuing PLT is related to a Branch PLT  Copy it over and remove the previous rel from the original Master PLT to the Branch PLT
                        FOR b_3
                            IN (SELECT r.toobjectid branchplt,
                                       r.relationshipid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = c_1.prilictypeobjid
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_PrimaryLicenseType',
                                           'MastertoBranch'))
                        LOOP
                            --Create the new relationship from the Master j_LicenseType to the Branch PLT
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'BranchPrimaryLicenseType'),
                                    t_lictypejobobjid,
                                    b_3.branchplt);
                            --remove the relationship from the previous Branch PLT to the Master PLT
                            api.pkg_relationshipupdate.remove(
                                b_3.relationshipid);
                        END LOOP;             --to Master Primary License Type

                        ------+++++ PLT is a Master of a Branch License Type
                        FOR b_4
                            IN (SELECT toobjectid masterltobjid,
                                       relationshipid
                                  FROM api.relationships
                                 WHERE fromobjectid = c_1.prilictypeobjid
                                   AND endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_PrimaryLicenseType',
                                           'MasterPrimaryLicenseType'))
                        LOOP
                            -- Remove rel from PLT to LT
                            api.pkg_relationshipupdate.remove(
                                b_4.relationshipid);
                            -- Relate the Branch to the Master
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'BranchLicenseType'),
                                    t_lictypejobobjid,
                                    b_4.masterltobjid);
                            --Set the ExpirationDate of the new Branch LT to the ExpirationDate of it's Master LT
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringMonth',
                                api.pkg_columnquery.VALUE(b_4.masterltobjid,
                                                          'ExpiringMonth'));
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringYear',
                                api.pkg_columnquery.VALUE(b_4.masterltobjid,
                                                          'ExpiringYear'));
                        END LOOP;
                    ------+++++
                    END IF;            -- Master/Branch License Type Candidate

                    BEGIN --Now look at the app again for possible Secondary License Types for this Primary
                        FOR c_3
                            IN (SELECT slt.licensetypecategoryobjectid
                                           ltcsecobjid,
                                       slt.relationshipid
                                           apprelpltsecltc,
                                       r2.toobjectid
                                           issseccatrelid,
                                       slt.istransferred,
                                       slt.fromslt
                                  FROM query.r_priltltcatsecondary  slt
                                       JOIN api.relationships r
                                           ON r.toobjectid =
                                              slt.licensetypecategoryobjectid --from LTC to PendingSLT
                                          AND r.endpointid = t_psltendpointid
                                       JOIN api.relationships r2
                                           ON r2.toobjectid = r.fromobjectid
                                          AND r2.endpointid = t_pltendpointid
                                          AND r2.fromobjectid =
                                              slt.primarylicensetypeobjectid
                                       JOIN query.r_issuelicenseplt iplt
                                           ON iplt.primarylicensetypeobjectid =
                                              slt.primarylicensetypeobjectid
                                 WHERE slt.primarylicensetypeobjectid =
                                       c_1.prilictypeobjid
                                   AND (api.pkg_columnquery.VALUE(
                                            r.fromobjectid,
                                            'Issue') =
                                        'Y'
                                     OR api.pkg_columnquery.VALUE(
                                            iplt.issuelicenseprocessid,
                                            'IssueAllLicenseTypes') =
                                        'Y')
                                   AND slt.sstatus NOT IN
                                           (SELECT UPPER(s.description)
                                              FROM api.statuses  s
                                                   JOIN api.jobstatuses js
                                                       ON js.statusid =
                                                          s.statusid
                                                      AND js.jobtypeid =
                                                          api.pkg_configquery.objectdefidforname(
                                                              'j_LicenseType')
                                             WHERE js.statustype IN
                                                       ('C', 'X')))
                        LOOP
                            -- Set the Issued Boolean when the SLT is included in the Issue process.
                            api.pkg_columnupdate.setvalue(
                                c_3.apprelpltsecltc,
                                'Issued',
                                'Y');
                            api.pkg_columnupdate.setvalue(
                                c_3.apprelpltsecltc,
                                'SStatus',
                                'ISSUED');
                            api.pkg_columnupdate.setvalue(c_3.issseccatrelid,
                                                          'Status',
                                                          'ISSUED');
                            -- Relate this Secondary License Type to the Primary License Type on the License
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_LicenseType',
                                        'LicTypeCatSecondary'),
                                    t_lictypejobobjid,
                                    c_3.ltcsecobjid);
                            -- Set the Status Date and Status on new Secondary License Types.
                            t_statusdate   :=
                                api.pkg_columnquery.datevalue(
                                    c_3.apprelpltsecltc,
                                    'StatusDate');
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'StatusDate',
                                                          t_statusdate);
                            -- Copy License Type Count for the Secondary License Type
                            pkg_copy.copystoredobjectdetails(
                                c_3.apprelpltsecltc,
                                t_newrelobjectid);
                            -- Set the Status Date and Status on new Secondary License Types.
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'Status',
                                                          'PENDING');
                            -- Set the batch flags on the secondary license types
                            pkg_batchtype.setbatchflags(
                                t_newrelobjectid,
                                a_includeinproducelicensebatch => 'Y',
                                a_includeindailybatch => 'Y');
                            -- Set the Ready to Issue Date on the secondary license types
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'ReadyToIssueDate',
                                                          t_readytoissuedate);

                            -- Set the type of issueance on the secondary license types
                            IF c_3.istransferred = 'N' THEN
                                api.pkg_columnupdate.setvalue(
                                    t_newrelobjectid,
                                    'TypeOfIssuance',
                                    c_1.typeofissuance);
                            ELSIF c_3.istransferred = 'Y' THEN
                                SELECT REGEXP_REPLACE(c_1.typeofissuance,
                                                      '[[:digit:]]{2}',
                                                      c_3.fromslt,
                                                      1,
                                                      1)
                                  INTO t_sectypeofissuance
                                  FROM DUAL;

                                api.pkg_columnupdate.setvalue(
                                    t_newrelobjectid,
                                    'TypeOfIssuance',
                                    t_sectypeofissuance);
                            END IF;

                            --api.pkg_errors.RaiseError(-20001, 'B)PriLicTypeObjId: ' || c_1.PriLicTypeObjId || ', LTCSecObjID: ' || c_3.LTCSecObjId);--TESTING ONLY
                            FOR c_dup
                                IN (SELECT d.duplicateid objectid
                                      FROM sitespecific.duplicate_t d
                                     WHERE d.primarylicensetypeobjectid =
                                           c_1.prilictypeobjid
                                       AND d.licensetypecategoryobjectid =
                                           c_3.ltcsecobjid)
                            LOOP
                                --Copy duplicate objects to License Type by setting the License Type Job ID
                                api.pkg_columnupdate.setvalue(
                                    c_dup.objectid,
                                    'LicenseTypeJobId',
                                    t_lictypejobobjid);
                                api.pkg_columnupdate.setvalue(
                                    c_dup.objectid,
                                    'RelationshipID',
                                    t_newrelobjectid);
                                api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                              'IssueDate',
                                                              SYSDATE);
                                api.pkg_columnupdate.setvalue(
                                    c_dup.objectid,
                                    'ReadyToIssueDate',
                                    t_readytoissuedate);
                                api.pkg_columnupdate.removevalue(
                                    c_dup.objectid,
                                    'BatchDate'); -- Gurpreet -- Issue # 2528 (ABC# 1915) ; Dup on Transfers Apps were not printing or earning in Daily Batch. Print Flag was not being updated, In PKG_BatchType.ProduceLicenses (if (dup_l.batchdate is null and t_DailyorRenewal = 'Daily'))

                                IF c_3.istransferred = 'N' THEN
                                    api.pkg_columnupdate.setvalue(
                                        t_newrelobjectid,
                                        'TypeOfIssuance',
                                        c_1.typeofissuance);
                                ELSIF c_3.istransferred = 'Y' THEN
                                    SELECT REGEXP_REPLACE(c_1.typeofissuance,
                                                          '[[:digit:]]{2}',
                                                          c_3.fromslt,
                                                          1,
                                                          1)
                                      INTO t_sectypeofissuance
                                      FROM DUAL;

                                    api.pkg_columnupdate.setvalue(
                                        t_newrelobjectid,
                                        'TypeOfIssuance',
                                        t_sectypeofissuance);
                                END IF;
                            END LOOP;
                        END LOOP;          -- c_3  Secondaries off new Primary

                        --Mantain Dups on post verify
                        api.pkg_columnupdate.setvalue(
                            t_lictypejobobjid,
                            'dup_IncludeInProduceLicBatchSe',
                            'Y');
                    EXCEPTION
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'ERROR relating New Secondary LT with New Primary License Type:'
                                || c_1.licensetypecode
                                || SQLERRM);
                    END;
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'ERROR with Primary License Type: '
                        || c_1.licensetypecode);
            END;
        END LOOP; -- c_1 Primary License Types on Application temporary placement

        -- SEE IF ANY PRIMARY OR SECONDARY LICENSE TYPE SHOULD BE REMOVED FROM THE LICENSE
        -- If it is not on the Application, then remove it from License.
        -- Grab Primary License Types (PLT) associated with the License which are not in status 'CANCEL'
        FOR c_4
            IN (SELECT r1.toobjectid prilictypeobjid,
                       r2.toobjectid ltcobjid,
                       ltc.licensetypecode -- Only using this for Error messages
                  FROM api.relationships  r1
                       JOIN api.relationships r2
                           ON r2.fromobjectid = r1.toobjectid
                          AND r2.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'j_LicenseType',
                                  'LicTypeCatPrimary')
                       JOIN query.o_licensetypecategory ltc
                           ON ltc.objectid = r2.toobjectid
                       JOIN query.j_licensetype lt
                           ON lt.objectid = r1.toobjectid
                       JOIN api.jobstatuses js
                           ON js.jobtypeid = lt.jobtypeid
                          AND js.statusid = lt.statusid
                          AND js.statustype NOT IN ('C', 'X') --issue 943 --and lt.StatusName <> 'CANCEL'
                 WHERE r1.fromobjectid = t_chnglicobjid
                   AND r1.endpointid =
                       api.pkg_configquery.endpointidforname('j_License',
                                                             'LicenseType'))
        LOOP
            BEGIN -- Is this Primary License Type on the Application?  If not, cancel it from License.
                SELECT r1.toobjectid, r1.fromobjectid
                  INTO t_liclictypcatpriobjid, t_licpltobjid
                  FROM query.o_licensetypecategory  ltc
                       JOIN api.relationships r1
                           ON r1.toobjectid = ltc.objectid
                          AND r1.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'o_PrimaryLicenseType',
                                  'LicTypeCatPrimary')
                       JOIN api.relationships r2
                           ON r2.toobjectid = r1.fromobjectid
                          AND r2.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'j_Application',
                                  'PrimaryLicenseType')
                 WHERE r2.fromobjectid = a_appobjectid
                   AND r1.toobjectid = c_4.ltcobjid;

                -- If code comes here the Primary on the License is on the Application,
                -- and therefore should remain on the License.
                -- Now evaluate this Primary on the License for any Secondaries.
                -- Each Secondary on the License must be on App; otherwise remove it from License.
                -- Update License Type Count for the Secondary, if Secondary is to remain on License.
                FOR c_5
                    IN (SELECT r1.toobjectid     ltcsecobjid,
                               r1.fromobjectid   priltobjid,
                               r1.relationshipid secrelid
                          FROM api.relationships  r
                               JOIN api.relationships r1
                                   ON r1.toobjectid = r.toobjectid
                                  AND r1.endpointid = t_psltendpointid
                               JOIN api.relationships r2
                                   ON r2.toobjectid = r1.fromobjectid
                                  AND r2.endpointid = t_pltendpointid
                               JOIN query.r_issuelicenseplt iplt
                                   ON iplt.primarylicensetypeobjectid =
                                      r2.toobjectid
                                  AND iplt.issuelicenseprocessid =
                                      a_processobjid
                                  AND iplt.primarylicensetypeobjectid =
                                      r2.fromobjectid
                         WHERE r.fromobjectid = c_4.prilictypeobjid
                           AND r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_LicenseType',
                                   'LicTypeCatSecondary')
                           AND (api.pkg_columnquery.VALUE(r2.fromobjectid,
                                                          'Issue') =
                                'Y'
                             OR api.pkg_columnquery.VALUE(
                                    iplt.issuelicenseprocessid,
                                    'IssueAllLicenseTypes') =
                                'Y'))
                LOOP
                    BEGIN -- Is this Secondary on the Application?  If not, remove it from License
                        SELECT r1.toobjectid, r1.relationshipid
                          INTO t_ltcsecobjid, t_apprelpltsecltc
                          FROM api.relationships  r1
                               JOIN api.relationships r2
                                   ON r2.toobjectid = r1.fromobjectid
                                  AND r2.endpointid =
                                      api.pkg_configquery.endpointidforname(
                                          'j_Application',
                                          'PrimaryLicenseType')
                         WHERE r2.fromobjectid = a_appobjectid
                           AND r1.toobjectid = c_5.ltcsecobjid
                           AND r1.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_PrimaryLicenseType',
                                   'LicTypeCatSecondary');

                        -- Copy License Type Count for the Secondary License Type, in case the count was changed by the Application
                        pkg_copy.copystoredobjectdetails(t_apprelpltsecltc,
                                                         c_5.secrelid);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN -- Remove Relationship to this Secondary License Type
                            api.pkg_relationshipupdate.remove(c_5.secrelid);
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'ERROR removing Secondary License Type: '
                                || SQLERRM);
                    END;
                END LOOP;               -- c_5 Existing Secondaries on License
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'ERROR with Primary License Type:'
                        || c_4.licensetypecode
                        || SQLERRM);
            END;
        END LOOP;                      -- c_4 Primary License Types on License

        --Issue any Secondary LTs for Existing License Types.
        sitespecific.pkg_issuelicense.issueslt(a_processobjid, a_appobjectid);

        IF t_lastissuelicenseprocess = 'Y' THEN
            FOR plt
                IN (SELECT r.licensetypeobjectid
                               prilictypeobjid,
                           api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                                     'LicenseTypeCode')
                               ltcode
                      FROM query.r_appprimarylicensetype r
                     WHERE r.applicationobjectid = a_appobjectid
                       AND api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                                     'Status') NOT IN
                               (SELECT UPPER(s.description)
                                  FROM api.statuses  s
                                       JOIN api.jobstatuses js
                                           ON js.statusid = s.statusid
                                          AND js.jobtypeid =
                                              api.pkg_configquery.objectdefidforname(
                                                  'j_LicenseType')
                                 WHERE js.statustype IN ('C', 'X')))
            LOOP
                FOR inv
                    IN (SELECT ai.relationshipid   appinvrelid,
                               ai.investigationjobid,
                               iplt.relationshipid applicpltrelid,
                               iplt.primarylicensetypejobid
                          FROM query.r_applicationinvestigation  ai
                               JOIN query.r_investigationprilicensetype iplt
                                   ON iplt.investigationjobid =
                                      ai.investigationjobid
                         WHERE iplt.primarylicensetypejobid =
                               plt.prilictypeobjid)
                LOOP
                    --Move from the Application and Primary License Type
                    api.pkg_relationshipupdate.remove(inv.appinvrelid,
                                                      SYSDATE);
                    api.pkg_relationshipupdate.remove(inv.applicpltrelid,
                                                      SYSDATE);
                    --To the New License and New License Type
                    t_investigationrel   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Investigation',
                                'License'),
                            inv.investigationjobid,
                            t_chnglicobjid);

                    BEGIN
                        SELECT llt.licensetypejobid
                          INTO t_lictypejobobjid
                          FROM query.r_licenselicensetype llt
                         WHERE llt.licensejobid = t_chnglicobjid
                           AND api.pkg_columnquery.VALUE(
                                   llt.licensetypejobid,
                                   'LicenseTypeCode') =
                               plt.ltcode;

                        t_applicableltinvrelid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_Investigation',
                                    'LicenseType'),
                                inv.investigationjobid,
                                t_lictypejobobjid);
                    EXCEPTION
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'Investigation Move Fail: Error Relating the Investigation to a License Type. '
                                || SQLERRM);
                    END;
                END LOOP;
            END LOOP;                                              -- PLT Loop

            -- Find all related Investigations that was not related a the Primary License Type
            -- then move it to the new License.
            FOR inv2 IN (SELECT ai.relationshipid, ai.investigationjobid
                           FROM query.r_applicationinvestigation ai
                          WHERE ai.applicationjobid = a_appobjectid)
            LOOP
                -- Move from the Application
                api.pkg_relationshipupdate.remove(inv2.relationshipid,
                                                  SYSDATE);
                -- To the New License
                t_investigationrel   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_Investigation',
                            'License'),
                        inv2.investigationjobid,
                        t_chnglicobjid);
            END LOOP;
        END IF;

        -- If the License already exists, remove the existing conditions before relating the current ones from the Application
        FOR c IN (SELECT r.relationshipid
                    FROM query.r_licensecondition r
                   WHERE r.licensejobid = t_chnglicobjid
                  UNION
                  SELECT a.relationshipid
                    FROM query.r_licenseadditioncondition a
                   WHERE a.licensejobid = t_chnglicobjid)
        LOOP
            api.pkg_relationshipupdate.remove(c.relationshipid);
        END LOOP;

        -- Copy Conditions to License
        t_endpointid   :=
            api.pkg_configquery.endpointidforname('j_License', 'Condition');

        FOR c IN (SELECT *
                    FROM query.r_applicationcondition r
                   WHERE r.applicationjobid = a_appobjectid)
        LOOP
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_chnglicobjid,
                                               c.conditionobjectid);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'DetailsCopied',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionText',
                                          c.conditiontext);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionCode',
                                          c.conditioncode);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionRelCount',
                                          c.conditionrelcount);
            api.pkg_columnupdate.setvalue(t_relationshipid, 'Sort', c.sort);
        END LOOP;

        -- Copy Additional Conditions to License
        t_endpointid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'AdditCondition');
        t_objectdefid   :=
            api.pkg_configquery.objectdefidforname('o_AdditionalCondition');

        FOR x
            IN (SELECT ac.objectid, ac.sort2, ac.conditiontext
                  FROM query.r_applicationadditioncondition  r
                       JOIN query.o_additionalcondition ac
                           ON ac.objectid = r.additionalconditionobjectid
                 WHERE r.applicationjobid = a_appobjectid)
        LOOP
            t_newobjectid   := api.pkg_objectupdate.new(t_objectdefid);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'ConditionText',
                                          x.conditiontext);
            api.pkg_columnupdate.setvalue(t_newobjectid, 'Sort2', x.sort2);
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_chnglicobjid,
                                               t_newobjectid);
        END LOOP;
    END issuetransfertoactivelicense;                      -- end of Procedure

    ----------------------------------------------------------------------------------------------------
    --  IssueChangeLicense() -- PUBLIC
    -- Change can be Stock Transfer or License Type Exchange OR BOTH.
    -- New License is not created; Changes to existing license as dictated by Application
    -- Capture any changes to DBAs
    -- Stock Transfer - replace Legal Entity structure from License with what Application shows.
    -- License Type Exchange - Make License Types on License reflect what Application shows
    ----------------------------------------------------------------------------------------------------
    PROCEDURE issuechangelicense(a_appobjectid   udt_id,
                                 a_processobjid  udt_id DEFAULT NULL)
    IS
        t_cnt                     INTEGER;
        t_lestodelete             udt_objectlist;
        t_statusdescription       VARCHAR2(100);
        t_appworddocmentepid      udt_id;
        t_appdbaepid              udt_id;
        t_licdbaepid              udt_id;
        t_licworddocumentepid     udt_id;
        t_isslicpltepid           udt_id;
        t_isslictypedefid         udt_id;
        t_lictypecatprimepid      udt_id;
        t_lictypecatsecepid       udt_id;
        t_ltmasterbranchepid      udt_id;
        t_ltprimbranchepid        udt_id;
        t_ltbranchltepid          udt_id;
        t_ltmasterepid            udt_id;
        t_pltlictypecatepid       udt_id;
        t_pltlictypecatsecepid    udt_id;
        t_pltmasterepid           udt_id;
        t_pltbranchtomasterepid   udt_id;
        t_pltmastertobranchepid   udt_id;
        t_pltmasterprimltepid     udt_id;
        t_investlicepid           udt_id;
        t_investltepid            udt_id;
    BEGIN
        t_appdefid   :=
            api.pkg_configquery.objectdefidforname('j_Application');
        t_dbadefid   := api.pkg_configquery.objectdefidforname('o_DBANames');
        t_appdbanamesreldefid   :=
            api.pkg_configquery.objectdefidforname('r_ApplicationDBANames');
        t_licdbanamesreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseDBANames');
        -- Application
        t_applegalentityappepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Applicant');
        t_applegalentityosmepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'OnSaleManager');
        t_applegalentityflepid    :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'FoodLesseeApp');   -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
        t_applegalentityp12epid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'P12Applicant');
        t_applegalentityprip12id   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'PrimaryP12Applicant');
        t_appworddocmentepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'ABCWordDocument');
        t_appdbaepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'DBANames');
        t_apppltepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'PrimaryLicenseType');
        t_lastissuelicenseprocess   :=
            api.pkg_columnquery.VALUE(a_processobjid, 'IsIssueAllLTs');
        -- License
        t_licdefid   :=
            api.pkg_configquery.objectdefidforname('j_License');
        t_liclelicenseeepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'LicenseeLegalEntity');
        t_licleosmepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'OSMLegalEntity');
        t_licleflepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'FoodLesseeLic');   -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
        t_liclep12epid   :=
            api.pkg_configquery.endpointidforname('j_License', 'P12Licensee');
        t_licleprip12epid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'PrimaryP12Licensee');
        t_licdbaepid   :=
            api.pkg_configquery.endpointidforname('j_License', 'DBANames');
        t_licworddocumentepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'ABCWordDocument');
        t_licltepid   :=
            api.pkg_configquery.endpointidforname('j_License', 'LicenseType');
        t_isslicpltepid   :=
            api.pkg_configquery.endpointidforname('p_IssueLicense',
                                                  'PrimaryLicenseType');
        t_isslictypedefid   :=
            api.pkg_configquery.objectdefidforname('p_IssueLicenseType');
        -- LicenseType
        t_lictypedefid   :=
            api.pkg_configquery.objectdefidforname('j_LicenseType');
        t_lictypecatprimepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'LicTypeCatPrimary');
        t_lictypecatsecepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'LicTypeCatSecondary');
        t_ltmasterbranchepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'MasterBranchLicenseType');
        t_ltprimbranchepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'BranchPrimaryLicenseType');
        t_ltbranchltepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'BranchLicenseType');
        t_ltmasterepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'MasterLicenseType');
        t_ltmasterbranchepid   :=
            api.pkg_configquery.endpointidforname('j_LicenseType',
                                                  'MasterBranchLicense');
        -- Rel Defs
        t_priltltcatprimaryreldef   :=
            api.pkg_configquery.objectdefidforname('r_PriLTLTCatPrimary');
        t_priltltcatsecondaryreldef   :=
            api.pkg_configquery.objectdefidforname('r_PriLTLTCatSecondary');
        t_appprilictypereldef   :=
            api.pkg_configquery.objectdefidforname('r_AppPrimaryLicenseType');
        t_liclelicenseereldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseLegalEntityLicensee');
        t_licleosmreldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseLegalEntityOSM');
        t_liclictypereldefid   :=
            api.pkg_configquery.objectdefidforname('r_LicenseLicenseType');
        t_lictypltcatprireldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseTypeLTCatPrimary');
        t_lictypltcatsecreldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_LicenseTypeLTCatSecondary');
        t_lictxfrfromreldefid   :=
            api.pkg_configquery.objectdefidforname(
                'r_ApplicationLicenseTransfer');
        t_psltendpointid   :=
            api.pkg_configquery.endpointidforname(
                'o_PendingSecondaryLicenseType',
                'PendLicTypeCatSecondary');
        -- PrimaryLicenseType EndPoints
        t_pltendpointid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'PendSecLicType');
        t_pltlictypecatepid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'LicTypeCatPrimary');
        t_pltlictypecatsecepid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'LicTypeCatSecondary');
        t_pltmasterepid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'MasterLicenseType');
        t_pltbranchtomasterepid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'BranchtoMaster');
        t_pltmastertobranchepid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'MastertoBranch');
        t_pltmasterprimltepid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'MasterPrimaryLicenseType');
        -- Investigate EndPoints
        t_investlicepid   :=
            api.pkg_configquery.endpointidforname('j_Investigation',
                                                  'License');
        t_investltepid   :=
            api.pkg_configquery.endpointidforname('j_Investigation',
                                                  'LicenseType');

        -- grab details from application.
        SELECT a.applicationtype,
               a.licensenumber,
               a.licensebeingchanged,
               a.licensetypeexchange,
               a.membershiptransfer,
               a.stocktransfer,
               a.externalfilenum,
               a.istemporarymailingaddress,
               a.conda,
               a.ispriorityapplication,
               a.felony,
               a.violation
          INTO t_applicationtype,
               t_licensenumber,
               t_licensebeingchanged,
               t_licensetypeexchange,
               t_membershiptransfer,
               t_stocktransfer,
               t_externalfilenum,
               t_tempaddr,
               t_governmentowned,
               t_priorityapplication,
               t_felony,
               t_violation
          FROM query.j_application a
         WHERE a.jobid = a_appobjectid;

        BEGIN
            -- Get the objectid of the license being changed
            SELECT c.licensejobid                               --c.ToObjectId
              INTO t_chnglicobjid
              FROM query.r_applicationlicense c
             WHERE c.applicationjobid = a_appobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       ' ERROR. Could not identify License being changed.'
                    || SQLERRM);
        END;

        -- Start of tasks performed regardless of Application Change Type.

        BEGIN  --copy Felony and Violation details from Application to License
            api.pkg_columnupdate.setvalue(t_chnglicobjid, 'Felony', t_felony);
            api.pkg_columnupdate.setvalue(t_chnglicobjid,
                                          'Violation',
                                          t_violation);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'ERROR copying Felony and Violation details. ' || SQLERRM);
        END;

        BEGIN                  --remove existing Premises Address relationship
            SELECT r.relationshipid
              INTO t_premaddrobjectid
              FROM query.r_licenseaddrpremises r
             WHERE r.licensejobid = t_chnglicobjid;

            api.pkg_relationshipupdate.remove(t_premaddrobjectid, SYSDATE);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;             --if there is no premises address do nothing
        END;

        BEGIN
            --Always Copy the Premises Address from the Application to the License
            SELECT r.addressobjectid                              --ToObjectId
              INTO t_premaddrobjectid
              FROM query.r_applicationpremaddr r
             WHERE r.applicationjobid = a_appobjectid;

            -- Relate Premises Address object to Application
            t_newrelobjectid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('j_License',
                                                          'Premises'),
                    t_chnglicobjid,
                    t_premaddrobjectid);
        EXCEPTION
            WHEN OTHERS THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'ERROR with Existing Premises Address. ' || SQLERRM);
        END;

        BEGIN                               -- Mailing Address for the license
            SELECT r.addressobjectid,
                   api.pkg_columnquery.VALUE(r.applicationjobid,
                                             'IsTemporaryMailingAddress')
              INTO t_mailaddrobjectid, t_tempaddr
              FROM query.r_applicationmailaddr r
             WHERE r.applicationjobid = a_appobjectid;

            SELECT r.relationshipid, r.maobjectid
              INTO t_licmailaddrrelid, t_licmailaddrobjectid
              FROM query.r_licenseaddrmailing r
             WHERE r.licensejobid = t_chnglicobjid;


            --if t_tempaddr <> 'Y' then
            -- Remove current mailing address, if exists, and replace with mail addr from app.
            -- if not a temporary address and this is not a P12 application then create the Mailing Address Rel
            IF t_tempaddr <> 'Y'
           AND p12applicantcount(a_appobjectid) = 0 THEN
                IF t_licmailaddrobjectid <> t_mailaddrobjectid
                OR (t_licmailaddrobjectid IS NULL
                AND t_mailaddrobjectid IS NOT NULL)
                OR (t_mailaddrobjectid IS NULL
                AND t_licmailaddrobjectid IS NOT NULL) THEN
                    api.pkg_columnupdate.setvalue(t_licmailaddrrelid,
                                                  'RunProcedureOnDeletion',
                                                  'Y');
                    api.pkg_relationshipupdate.remove(t_licmailaddrrelid);
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'MailingAddress'),
                            t_chnglicobjid,
                            t_mailaddrobjectid);
                END IF;
            END IF;                          -- Temporary Mailing Address test
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_newrelobjectid   := NULL;
        END;

                  BEGIN                  --remove existing Email Address relationship -- WO 20669 Added by Pawan for Price posting email Change License
            SELECT r.relationshipid
              INTO t_emailaddrobjectid
              FROM query.r_EmailsLicense r
             WHERE r.licensejobid = t_chnglicobjid;

            api.pkg_relationshipupdate.remove(t_emailaddrobjectid, SYSDATE);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;             --if there is no email address do nothing
        END;

        BEGIN
            --Always Copy the Emai Address from the Application to the License
            SELECT r.EmailObjectId                              --ToObjectId
              INTO t_emailaddrobjectid
              FROM query.r_EmailsApplication r
             WHERE r.applicationjobid = a_appobjectid;

            -- Relate Email Address object
            t_newrelobjectid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('j_License',
                                                          'LicenseEmail'),
                    t_chnglicobjid,
                    t_emailaddrobjectid);
        EXCEPTION
             WHEN NO_DATA_FOUND THEN
                    t_newrelobjectid   := NULL;
        END; --End WO 20669 Added by Pawan for Price posting email Change License


        -- Find the current revision of Conditions Document ABC-172 (if exists), and relate to License
        BEGIN
            t_abc172docid := GetConditionalDoc(a_appobjectid);
            IF t_abc172docid IS NOT NULL THEN
                t_endpointid   := t_licworddocumentepid;
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_chnglicobjid,
                                                   t_abc172docid);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;          -- Conditions document is option; just move on.
        END;

        BEGIN      -- Update/Add DBAs on the License to match Application info
            FOR c_dbaapp IN (SELECT d.dba      dbanameapp, -- DBAs on the Application
                                    d.active,
                                    d.objectid dbaappobjid,
                                    d.primarydba
                               FROM query.o_dbanames  d
                                    JOIN api.relationships r
                                        ON r.toobjectid = d.objectid
                                       AND r.endpointid = t_appdbaepid
                              WHERE r.fromobjectid = a_appobjectid)
            LOOP
                BEGIN      -- Does this DBA from the App exist on the license?
                    SELECT d.objectid
                      INTO t_dbalicobjid
                      FROM query.o_dbanames  d
                           JOIN api.relationships r
                               ON r.toobjectid = d.objectid
                              AND r.endpointid = t_licdbaepid
                     WHERE r.fromobjectid = t_chnglicobjid
                       AND d.dba = c_dbaapp.dbanameapp;

                    api.pkg_columnupdate.setvalue(t_dbalicobjid,
                                                  'Active',
                                                  c_dbaapp.active);
                    api.pkg_columnupdate.setvalue(t_dbalicobjid,
                                                  'PrimaryDBA',
                                                  c_dbaapp.primarydba);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_dbanewobjid   :=
                            api.pkg_objectupdate.new(t_dbadefid);

                        pkg_copy.copystoredobjectdetails(
                            c_dbaapp.dbaappobjid,
                            t_dbanewobjid);

                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(t_licdbaepid,
                                                           t_chnglicobjid,
                                                           t_dbanewobjid);
                END;
            END LOOP;                                   -- DBAs on Application
        END;

        BEGIN                -- find DBAs on the License which are not on App.
            FOR c_dbalic IN (SELECT d.objectid dbaobjidlic, d.dba
                               FROM query.o_dbanames  d
                                    JOIN api.relationships r
                                        ON r.toobjectid = d.objectid
                                       AND r.endpointid = t_licdbaepid
                              WHERE r.fromobjectid = t_chnglicobjid)
            LOOP
                BEGIN
                    SELECT d.dba
                      INTO t_dbanameapp
                      FROM query.o_dbanames  d
                           JOIN api.relationships r
                               ON r.toobjectid = d.objectid
                              AND endpointid = t_appdbaepid
                     WHERE r.fromobjectid = a_appobjectid
                       AND d.dba = c_dbalic.dba;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- Update the details of this existing DBA to match app.
                        api.pkg_columnupdate.setvalue(c_dbalic.dbaobjidlic,
                                                      'Active',
                                                      'N');
                        api.pkg_columnupdate.setvalue(c_dbalic.dbaobjidlic,
                                                      'PrimaryDBA',
                                                      'N');
                END;
            END LOOP;           -- DBAs on License that are not on Application
        EXCEPTION
            WHEN OTHERS THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    ' ERROR evaluating existing DBAs on License.' || SQLERRM);
        END;   --End of tasks performed regardless of Application Change Type.

        -- grab all current LEs on the License
        FOR c_lelic
            IN (SELECT c.relationshipid relationshipidlicle,
                       c.toobjectid     leobjectid,
                       c.endpointid     endpointid
                  FROM api.relationships c
                 WHERE c.endpointid IN (t_liclelicenseeepid,
                                        t_licleosmepid,
                                        t_licleflepid,   -- 05/08/2025PK               Added Food Lessee to Original, change anf trannsfer application code 
                                        t_liclep12epid,
                                        t_licleprip12epid)
                   AND c.fromobjectid = t_chnglicobjid)
        LOOP
            --Remove Legal Entity's Children
            IF c_lelic.endpointid NOT IN (t_liclep12epid, t_licleprip12epid) THEN
                t_lestodelete   := api.udt_objectlist();
                sitespecific.pkg_legalentity.getlegalentitychildren(
                    c_lelic.leobjectid,
                    t_lestodelete);

                FOR c_2 IN 1 .. t_lestodelete.COUNT
                LOOP
                    api.pkg_objectupdate.remove(t_lestodelete(c_2).objectid);
                END LOOP;

                -- Remove Legal Entity object
                api.pkg_objectupdate.remove(c_lelic.leobjectid);
            ELSE
                api.pkg_relationshipupdate.remove(
                    c_lelic.relationshipidlicle);
            END IF;
        END LOOP;                       -- grab all current LEs on the License

        BEGIN                -- Add Legal Entities from Application to License
            FOR c_le IN (SELECT toobjectid, endpointid
                           FROM api.relationships
                          WHERE fromobjectid = a_appobjectid
                            AND endpointid IN (t_applegalentityappepid,
                                               t_applegalentityosmepid,
                                               t_applegalentityflepid,
                                               t_applegalentityp12epid,
                                               t_applegalentityprip12id))
            LOOP
                IF c_le.endpointid NOT IN
                       (t_applegalentityp12epid, t_applegalentityprip12id) THEN -- Copy the Legal Entity associated with the Application
                    t_legalentityobjid   :=
                        pkg_legalentity.legalentitycopy(c_le.toobjectid);
                ELSE -- the existing P12 legal entity will be related to the license.
                    t_legalentityobjid   := c_le.toobjectid;
                END IF;

                -- Get the endpoint for the rel from license to le
                CASE
                    WHEN c_le.endpointid = t_applegalentityappepid THEN
                        t_createrelendpointid   := t_liclelicenseeepid;
                    WHEN c_le.endpointid = t_applegalentityosmepid THEN 
                        t_createrelendpointid   := t_licleosmepid;
                    WHEN c_le.endpointid = t_applegalentityflepid THEN 
                        t_createrelendpointid   := t_licleflepid;    -- 05/08/2025 PK               Added Food Lessee to Original, change anf trannsfer application code 
                    WHEN c_le.endpointid = t_applegalentityp12epid THEN
                        t_createrelendpointid   := t_liclep12epid;
                    WHEN c_le.endpointid = t_applegalentityprip12id --When looking at the Primary P12 Relationship Copy the rel
                                                                    THEN
                        t_createrelendpointid   := t_licleprip12epid;
                END CASE;

                -- Relate the Legal Entity to the License
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_createrelendpointid,
                                                   t_chnglicobjid,
                                                   t_legalentityobjid);
            END LOOP;                         -- Legal Entities on Application
        END;                                                 -- Legal Entities

        -- For Change applications with type License Type Exchange.
        -- Add additional License Type Job to License, per Primary License Type on Application.
        -- Update existing License Type Job to add or drop Secondary License Type, per Pri Lic Type on Application
        -- Cancel License Type Job which doesn't have corresponding Primary License Type on Application
        -- Remove secondaries off license which are not found on application.
        -- For every PLT move the related investigation to the License job.
        -- All License Types on License will have "IncludeInBatch" flag set to "Y".

        -- Get the ready to issue date from the Application
        t_readytoissuedate   :=
            api.pkg_columnquery.datevalue(a_appobjectid, 'ReadyToIssueDate');

        -- Grab Primary License Types (PLT) associated with the Application
        FOR c_1
            IN (SELECT r1.toobjectid
                           prilictypeobjid,
                       r2.toobjectid
                           ltcobjid,
                       api.pkg_columnquery.VALUE(r2.toobjectid,
                                                 'LicenseTypeCode')
                           licensetypecode,
                       api.pkg_columnquery.VALUE(r1.toobjectid,
                                                 'TypeofIssuance')
                           typeofissuance,
                       api.pkg_columnquery.VALUE(r1.toobjectid,
                                                 'BranchApplies')
                           branchapplies
                  FROM api.relationships  r1
                       JOIN api.relationships ilt
                           ON ilt.toobjectid = r1.toobjectid
                          AND ilt.fromobjectid = a_processobjid
                       JOIN api.relationships r2
                           ON r2.fromobjectid = r1.toobjectid
                          AND r2.endpointid = t_pltlictypecatepid
                 WHERE r1.fromobjectid = a_appobjectid
                   AND r1.endpointid = t_apppltepid
                   AND ilt.endpointid = t_isslicpltepid
                   AND (api.pkg_columnquery.VALUE(ilt.relationshipid,
                                                  'Issue') =
                        'Y'
                     OR (api.pkg_columnquery.VALUE(ilt.fromobjectid,
                                                   'IssueAllLicenseTypes') =
                         'Y'
                     AND api.pkg_columnquery.VALUE(r1.toobjectid, 'Issued') =
                         'N'))
                   AND api.pkg_columnquery.VALUE(r1.toobjectid, 'Status') NOT IN
                           (SELECT UPPER(s.description)
                              FROM api.statuses  s
                                   JOIN api.jobstatuses js
                                       ON js.statusid = s.statusid
                                      AND js.jobtypeid = t_lictypedefid
                             WHERE js.statustype IN ('C', 'X')))
        LOOP
            -- Set the Issued Boolean when the PLT is included in the Issue process.
            api.pkg_columnupdate.setvalue(c_1.prilictypeobjid, 'Issued', 'Y');

            IF api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'Status') =
               'PENDING' THEN
                api.pkg_columnupdate.setvalue(c_1.prilictypeobjid,
                                              'Status',
                                              'ISSUED');
            END IF;

            BEGIN --Is this Primary License Type already on the License as a Primary?  If not, add a License Type Job to License
                SELECT r1.toobjectid, r1.fromobjectid, r2.toobjectid
                  INTO t_liclictypcatpriobjid,
                       t_licpltobjid,
                       t_lictypejobobjid
                  FROM api.relationships  r1
                       JOIN api.relationships r2
                           ON r2.toobjectid = r1.fromobjectid
                          AND r2.endpointid = t_licltepid
                 WHERE r2.fromobjectid = t_chnglicobjid
                   AND r1.toobjectid = c_1.ltcobjid
                   AND r1.endpointid = t_lictypecatprimepid;

                -- If flow gets here, License Type Category - Primary already exists on License side
                --set details on the j_LT based on the values from the o_PLT
                --first set this detail to 'Y' to allow for the Gallonage Range to be set to null prior to the Branch LT rel being set
                api.pkg_columnupdate.setvalue(t_licpltobjid,
                                              'IsChangeProcRunning',
                                              'Y');
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'DesignatedExpirationDate',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'DesignatedExpirationDate'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'COND1C',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'COND1C'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'COND8',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'COND8'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'COND9',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'COND9'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'COND2',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'COND2'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'CONDA',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'CONDA'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'CONDD',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'CONDD'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'CONDI',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'CONDI'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'COND5',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'COND5'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'CONDR',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid, 'CONDR'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'ConditionEndDate',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'ConditionEndDate'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'BondedWinery',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'BondedWinery'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'GallonageRange',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'GallonageRange'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'AdditionalMillionGallons',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'AdditionalMillionGallons'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'NumberOfMonthsLicensed',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'NumberOfMonthsLicensed'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'SeasonStartMonth',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'SeasonStartMonth'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'PrimaryCount',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'PrimaryCount'));
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'StatusDate',
                    api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                              'StatusDate'));
                api.pkg_columnupdate.setvalue(t_licpltobjid,
                                              'TypeofIssuance',
                                              c_1.typeofissuance);

                -- Set flags on LT
                api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                              'IncludeInChangeAppBatch',
                                              'Y');
                api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                              'ReadyToIssueDate',
                                              t_readytoissuedate);
                api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                              'TypeofIssuance',
                                              c_1.typeofissuance);
                -- Set the batch flags
                pkg_batchtype.setbatchflags(
                    a_lictypejobid => t_lictypejobobjid,
                    a_includeinproducelicensebatch => 'Y',
                    a_includeindailybatch => 'Y');

                /********************************************Testing***********************************************************************/
                FOR b_1 IN (SELECT toobjectid masterltobjid, relationshipid
                              FROM api.relationships
                             WHERE fromobjectid = c_1.prilictypeobjid
                               AND endpointid = t_pltmasterepid)
                LOOP
                    api.pkg_relationshipupdate.remove(b_1.relationshipid);
                END LOOP;

                --get the relationship of when the issuing PLT is related to a Master PLT  Copy it over and remove the previous rel from the original Branch PLT to the Master PLT
                FOR b_2
                    IN (SELECT r.toobjectid     masterplt,
                               r.relationshipid tomasterrelid
                          FROM api.relationships r
                         WHERE r.fromobjectid = c_1.prilictypeobjid
                           AND r.endpointid = t_pltbranchtomasterepid)
                LOOP
                    api.pkg_relationshipupdate.remove(b_2.tomasterrelid);
                END LOOP;                     --to Master Primary License Type

                --get the relationship of when the issuing PLT is related to a Branch PLT  Copy it over and remove the previous rel from the original Master PLT to the Branch PLT
                FOR b_3 IN (SELECT r.toobjectid branchplt, r.relationshipid
                              FROM api.relationships r
                             WHERE r.fromobjectid = c_1.prilictypeobjid
                               AND r.endpointid = t_pltmastertobranchepid)
                LOOP
                    api.pkg_relationshipupdate.remove(b_3.relationshipid);
                END LOOP;                     --to Master Primary License Type

                ------+++++ PLT is a Master of a Branch License Type
                FOR b_4 IN (SELECT toobjectid masterltobjid, relationshipid
                              FROM api.relationships
                             WHERE fromobjectid = c_1.prilictypeobjid
                               AND endpointid = t_pltmasterprimltepid)
                LOOP
                    api.pkg_relationshipupdate.remove(b_4.relationshipid);
                END LOOP;

                /********************************************Testing************************************************************************/

                -- Now find License Type Category - Secondary from Primary License Type on Application
                -- Objective: Add any new Secondary License Types from the App to the License
                FOR c_2
                    IN (SELECT slt.licensetypecategoryobjectid
                                   ltcsecobjid,
                               slt.relationshipid
                                   apprelpltsecltc,
                               r2.toobjectid
                                   issseccatrelid,
                               api.pkg_columnquery.VALUE(r2.fromobjectid,
                                                         'LicenseTypeCode')
                                   masterltcode
                          FROM query.r_priltltcatsecondary  slt
                               JOIN api.relationships r
                                   ON r.toobjectid =
                                      slt.licensetypecategoryobjectid --from LTC to PendingSLT
                                  AND r.endpointid = t_psltendpointid
                               JOIN api.relationships r2
                                   ON r2.toobjectid = r.fromobjectid
                                  AND r2.endpointid = t_pltendpointid
                                  AND r2.fromobjectid =
                                      slt.primarylicensetypeobjectid
                               JOIN query.r_issuelicenseplt iplt
                                   ON iplt.primarylicensetypeobjectid =
                                      slt.primarylicensetypeobjectid
                         WHERE slt.primarylicensetypeobjectid =
                               c_1.prilictypeobjid
                           AND iplt.issuelicenseprocessid = a_processobjid
                           AND (api.pkg_columnquery.VALUE(r.fromobjectid,
                                                          'Issue') =
                                'Y'
                             OR api.pkg_columnquery.VALUE(
                                    iplt.issuelicenseprocessid,
                                    'IssueAllLicenseTypes') =
                                'Y')
                           AND api.pkg_columnquery.VALUE(slt.relationshipid,
                                                         'SStatus') NOT IN
                                   (SELECT UPPER(s.description)
                                      FROM api.statuses  s
                                           JOIN api.jobstatuses js
                                               ON js.statusid = s.statusid
                                              AND js.jobtypeid =
                                                  t_lictypedefid
                                     WHERE js.statustype IN ('C', 'X')))
                LOOP
                    -- Set the Issued Boolean when the SLT is included in the Issue process.
                    api.pkg_columnupdate.setvalue(c_2.apprelpltsecltc,
                                                  'Issued',
                                                  'Y');
                    api.pkg_columnupdate.setvalue(c_2.issseccatrelid,
                                                  'Issued',
                                                  'Y');

                    IF api.pkg_columnquery.VALUE(c_2.apprelpltsecltc,
                                                 'SStatus') =
                       'PENDING' THEN
                        api.pkg_columnupdate.setvalue(c_2.apprelpltsecltc,
                                                      'SStatus',
                                                      'ISSUED');
                        api.pkg_columnupdate.setvalue(c_2.issseccatrelid,
                                                      'Status',
                                                      'ISSUED');
                    END IF;

                    -- Is this Secondary Already on the License?  If yes, then only update the Count detail.
                    BEGIN
                        SELECT r1.toobjectid,
                               r1.fromobjectid,
                               r1.relationshipid              -- r1.EndPointId
                          INTO t_liclictypcatpriobjid,
                               t_licpltobjid,
                               t_licrelltsecltc
                          FROM api.relationships  r1
                               JOIN api.relationships r2
                                   ON r2.toobjectid = r1.fromobjectid
                                  AND r2.endpointid = t_licltepid
                         WHERE r2.fromobjectid = t_chnglicobjid
                           AND api.pkg_columnquery.VALUE(r2.toobjectid,
                                                         'LicenseTypeCode') =
                               c_2.masterltcode
                           AND r1.toobjectid = c_2.ltcsecobjid
                           AND r1.endpointid = t_lictypecatsecepid;

                        pkg_copy.copystoredobjectdetails(c_2.apprelpltsecltc,
                                                         t_licrelltsecltc);
                        api.pkg_columnupdate.setvalue(t_licrelltsecltc,
                                                      'TypeOfIssuance',
                                                      c_1.typeofissuance);
                        api.pkg_columnupdate.setvalue(
                            t_licrelltsecltc,
                            'IncludeInChangeAppBatch',
                            'Y');
                        api.pkg_columnupdate.setvalue(t_licrelltsecltc,
                                                      'ReadyToIssueDate',
                                                      t_readytoissuedate);
                        -- Set the batch flags
                        pkg_batchtype.setbatchflags(
                            a_lictypejobid => t_licrelltsecltc,
                            a_includeinproducelicensebatch => 'Y',
                            a_includeindailybatch => 'Y');

                        --Duplicates
                        FOR c_dup
                            IN (SELECT d.duplicateid objectid,
                                       d.licensetypecategoryobjectid,
                                       d.description,
                                       od.dupnumber
                                  FROM sitespecific.duplicate_t  d
                                       JOIN query.o_duplicate od
                                           ON od.objectid = d.duplicateid
                                 WHERE d.primarylicensetypeobjectid =
                                       c_1.prilictypeobjid
                                   AND d.licensetypecategoryobjectid =
                                       t_liclictypcatpriobjid)
                        LOOP
                            --Copy duplicate objects to License Type by setting the License Type Job ID
                            t_newobjectid   := NULL;

                            BEGIN
                                SELECT d.duplicateid objectid
                                  INTO t_newobjectid
                                  FROM sitespecific.duplicate_t  d
                                       JOIN query.o_duplicate od
                                           ON od.objectid = d.duplicateid
                                 WHERE d.relationshipid = t_licrelltsecltc
                                   AND od.dupnumber = c_dup.dupnumber;

                                --api.pkg_errors.RaiseError(-20001, 'Existing Object ID: ' || t_newObjectId); --BA DEBUGGING
                                pkg_copy.copystoredobjectdetails(
                                    c_dup.objectid,
                                    t_newobjectid);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'LicenseTypeJobId',
                                    t_licpltobjid);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'Description',
                                    c_dup.description);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'RelationshipID',
                                    t_licrelltsecltc);
                                api.pkg_columnupdate.setvalue(t_newobjectid,
                                                              'IssueDate',
                                                              SYSDATE);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'ReadyToIssueDate',
                                    t_readytoissuedate);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'TypeOfIssuance',
                                    c_1.typeofissuance);
                                api.pkg_columnupdate.removevalue(
                                    t_newobjectid,
                                    'BatchDate'); -- Gurpreet -- Issue # 2528 (ABC# 1915) ; Dup on Transfers Apps were not printing or earning in Daily Batch. Print Flag was not being updated, In PKG_BatchType.ProduceLicenses (if (dup_l.batchdate is null and t_DailyorRenewal = 'Daily'))
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    --Create new duplicates on License Type
                                    --api.pkg_errors.RaiseError(-20001, 'Dup BA Debugging - olddupnumber: ' || c_dup.dupnumber || ' olddescription: ' || c_dup.Description );--BA DEBUGGING
                                    t_newobjectid   :=
                                        api.pkg_objectupdate.new(
                                            api.pkg_configquery.objectdefidforname(
                                                'o_Duplicate'));

                                    --  Copy the Duplicate Details
                                    --note that it is important to set the license type category object id before anything else otherwise it errors.
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'LicenseTypeCategoryObjectID',
                                        c_dup.licensetypecategoryobjectid);
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'Description',
                                        c_dup.description);
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'RelationshipID',
                                        t_licrelltsecltc);
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'LicenseTypeJobID',
                                        t_lictypejobobjid);
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'IssueDate',
                                        SYSDATE);
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'ReadyToIssueDate',
                                        t_readytoissuedate);
                                    pkg_copy.copystoredobjectdetails(
                                        c_dup.objectid,
                                        t_newobjectid);
                            END;
                        END LOOP;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            -- Relate this Secondary License Type to the Existing Primary License Type on the License
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    t_lictypecatsecepid,
                                    t_licpltobjid,
                                    c_2.ltcsecobjid);
                            -- Set the Status Date and Status on the New License Type
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'StatusDate',
                                                          SYSDATE);
                            -- Copy License Type Count for the Secondary License Type
                            pkg_copy.copystoredobjectdetails(
                                c_2.apprelpltsecltc,
                                t_newrelobjectid);
                            -- Set the Status Date and Status on the New License Type
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'Status',
                                                          'PENDING');
                            -- Set the Ready To Issue Date --HotFix22 Part One
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'ReadyToIssueDate',
                                                          t_readytoissuedate);
                            -- Set the Type Of Issuance for the secondary types. HotFix22 Part One
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'TypeOfIssuance',
                                                          'DOR');
                            api.pkg_columnupdate.setvalue(
                                t_newrelobjectid,
                                'IncludeInChangeAppBatch',
                                'Y');
                            -- Set the Batch Flags
                            sitespecific.pkg_batchtype.setbatchflags(
                                a_lictypejobid => t_newrelobjectid,
                                a_includeinproducelicensebatch => 'Y',
                                a_includeindailybatch => 'Y');

                            --Duplicates
                            FOR c_dup
                                IN (SELECT d.duplicateid objectid,
                                           d.licensetypecategoryobjectid,
                                           d.description
                                      FROM sitespecific.duplicate_t d
                                     WHERE d.primarylicensetypeobjectid =
                                           c_1.prilictypeobjid --t_LicPLTObjId
                                       AND d.licensetypecategoryobjectid =
                                           c_2.ltcsecobjid)
                            LOOP
                                --Create new duplicates on License Type
                                t_newobjectid   :=
                                    api.pkg_objectupdate.new(
                                        api.pkg_configquery.objectdefidforname(
                                            'o_Duplicate'));

                                --  Copy the Duplicate Details
                                --note that it is important to set the license type category object id before anything else otherwise it errors.
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'LicenseTypeCategoryObjectID',
                                    c_dup.licensetypecategoryobjectid);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'Description',
                                    c_dup.description);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'RelationshipId',
                                    t_newrelobjectid);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'LicenseTypeJobID',
                                    t_lictypejobobjid);
                                api.pkg_columnupdate.setvalue(t_newobjectid,
                                                              'IssueDate',
                                                              SYSDATE);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'ReadyToIssueDate',
                                    t_readytoissuedate);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'TypeOfIssuance',
                                    'DOR');
                                pkg_copy.copystoredobjectdetails(
                                    c_dup.objectid,
                                    t_newobjectid);
                                api.pkg_columnupdate.removevalue(
                                    t_newobjectid,
                                    'BatchDate'); -- Gurpreet -- Issue # 2528 (ABC# 1915) ; Dup on Transfers Apps were not printing or earning in Daily Batch. Print Flag was not being updated, In PKG_BatchType.ProduceLicenses (if (dup_l.batchdate is null and t_DailyorRenewal = 'Daily'))
                            END LOOP;
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'ERROR relating Secondary LT with Existing Primary License Type:'
                                || c_1.licensetypecode
                                || SQLERRM);
                    END;
                END LOOP; -- c_2  Secondaries on the Application being added to existing Primary on License

                -- Maintian Dups for the Secondary Relationships
                api.pkg_columnupdate.setvalue(
                    t_licpltobjid,
                    'dup_IncludeInProduceLicBatchSe',
                    'Y');
                t_statusdescription   :=
                    api.pkg_columnquery.VALUE(t_licpltobjid,
                                              'StatusDescription');

                -- For existing License Types set the batch flags if the status is in an Initial or Intermediate status type
                SELECT COUNT(*)
                  INTO t_cnt
                  FROM api.processtypes  apt
                       JOIN api.processoutcomes apo
                           ON apo.processtypeid = apt.processtypeid
                       JOIN api.statuschanges astc
                           ON astc.processoutcomeid = apo.processoutcomeid
                       JOIN api.statuses as1
                           ON as1.statusid = astc.fromstatusid
                       JOIN api.jobstatuses ajs
                           ON ajs.statusid = as1.statusid
                          AND ajs.jobtypeid = apo.jobtypeid
                 WHERE apt.processtypeid = t_isslictypedefid
                   AND apo.jobtypeid = (SELECT jobtypeid
                                          FROM api.jobs
                                         WHERE jobid = t_licpltobjid)
                   AND as1.description = t_statusdescription
                   AND ajs.statustype IN ('I', 'O');

                IF (t_cnt > 0) THEN
                    pkg_batchtype.setbatchflags(
                        a_lictypejobid => t_licpltobjid,
                        a_includeinproducelicensebatch => 'Y',
                        a_includeindailybatch => 'Y');
                END IF;

                BEGIN
                    --update the existing License Types for the Branch/Master relationships according to the o_PLT
                    --for the o_PLT that are Branch LTs (with Master j_LT) delete the previous rels from Branch j_LT to Master j_LT
                    FOR b_1
                        IN (SELECT j.jobid,
                                   r.toobjectid     masterltjobid,
                                   r.relationshipid branjlttomastltrelid
                              FROM api.jobs  j
                                   LEFT OUTER JOIN api.relationships r
                                       ON r.fromobjectid = j.jobid
                                      AND r.endpointid = t_ltmasterepid
                                   LEFT OUTER JOIN api.relationships r1
                                       ON r1.fromobjectid = j.jobid
                                      AND r1.endpointid =
                                          t_ltmasterbranchepid
                             WHERE j.jobid = t_licpltobjid)
                    LOOP
                        SELECT r1.toobjectid,
                               r1.relationshipid,
                               r1.endpointid
                          INTO t_masterltobjid,
                               t_relationshipid,
                               t_endpointid
                          FROM api.relationships r1
                         WHERE r1.fromobjectid = c_1.prilictypeobjid
                           AND (r1.endpointid = t_pltmasterepid
                             OR r1.endpointid = t_pltbranchtomasterepid);

                        --Delete the relationship so that the new ones created are the most recent and updated
                        IF b_1.branjlttomastltrelid IS NOT NULL THEN
                            api.pkg_relationshipupdate.remove(
                                b_1.branjlttomastltrelid);
                        ELSE
                            NULL;
                        END IF;

                        --create new rels from the NEW Branch j_LT to the Master j_LT that the Branch o_PLT is related to
                        IF t_masterltobjid IS NOT NULL THEN
                            -- Remove the rel from the PLT to the Master LT
                            api.pkg_relationshipupdate.remove(
                                t_relationshipid);
                            api.pkg_columnupdate.setvalue(
                                c_1.prilictypeobjid,
                                'IsBranchS',
                                'Y');

                            -- If the PLT is the Branch of a j_LT, then update the Change LT to this rel
                            IF t_endpointid = t_pltmasterepid THEN
                                t_newrelobjectid   :=
                                    api.pkg_relationshipupdate.new(
                                        t_ltmasterepid,
                                        t_licpltobjid,
                                        t_masterltobjid);
                                --and set the expirationdate of the new LT to the expiration date of it's Master
                                api.pkg_columnupdate.setvalue(
                                    t_licpltobjid,
                                    'ExpiringMonth',
                                    api.pkg_columnquery.VALUE(
                                        t_masterltobjid,
                                        'ExpiringMonth'));
                                api.pkg_columnupdate.setvalue(
                                    t_licpltobjid,
                                    'ExpiringYear',
                                    api.pkg_columnquery.VALUE(
                                        t_masterltobjid,
                                        'ExpiringYear'));
                            -- If the PLT is a Branch of a o_PLT, then update the Change LT to this rel
                            ELSIF t_endpointid = t_pltbranchtomasterepid THEN
                                t_newrelobjectid   :=
                                    api.pkg_relationshipupdate.new(
                                        t_ltmasterbranchepid,
                                        t_licpltobjid,
                                        t_masterltobjid);
                            END IF;
                        END IF;

                        t_relationshipid   := b_1.branjlttomastltrelid;
                    END LOOP;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN --go ahead and delete the old relationship
                        IF t_relationshipid IS NOT NULL THEN
                            --Delete the relationship so that the new ones created are the most recent and updated
                            api.pkg_relationshipupdate.remove(
                                t_relationshipid);
                        ELSE
                            NULL;
                        END IF;
                END;

                --Set the boolean back to 'N' so that the Raise Error condition will be checked again
                api.pkg_columnupdate.setvalue(t_licpltobjid,
                                              'IsChangeProcRunning',
                                              'N');
            EXCEPTION
                WHEN NO_DATA_FOUND THEN  -- Add this Primary LT Cat to License
                    -- Create License Type Job, relate to Lic Type Cat
                    t_lictypejobobjid   :=
                        api.pkg_objectupdate.new(t_lictypedefid);
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_lictypecatprimepid,
                                                       t_lictypejobobjid,
                                                       c_1.ltcobjid);

                    -- If this PLT is transferred, log this to the License Transfers table
                    IF api.pkg_columnquery.VALUE(c_1.prilictypeobjid,
                                                 'IsTransferred') =
                       'Y' THEN
                        -- Log the Transfer with the License Transfers object
                        pkg_issuelicense.loglicensetransfer(
                            t_lictypejobobjid,
                            c_1.licensetypecode,
                            t_licensenumber,
                            c_1.prilictypeobjid,
                            a_appobjectid);
                    END IF;

                    -- Copy License Type details from App
                    pkg_copy.copystoredobjectdetails(c_1.prilictypeobjid,
                                                     t_lictypejobobjid);
                    api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                                  'ReadyToIssueDate',
                                                  t_readytoissuedate);
                    api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                                  'TypeofIssuance',
                                                  c_1.typeofissuance);
                    api.pkg_columnupdate.setvalue(t_lictypejobobjid,
                                                  'IncludeInChangeAppBatch',
                                                  'Y');
                    -- For New Primary LT set the batch flags
                    pkg_batchtype.setbatchflags(
                        a_lictypejobid => t_lictypejobobjid,
                        a_includeinproducelicensebatch => 'Y',
                        a_includeindailybatch => 'Y');
                    -- Relate newly created License Type Job to License
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_licltepid,
                                                       t_chnglicobjid,
                                                       t_lictypejobobjid);
                    -- Set Expiring Month and Year
                    pkg_issuelicense.setexpmonthyear(a_appobjectid,
                                                     SYSDATE,
                                                     c_1.prilictypeobjid,
                                                     t_lictypejobobjid);

                    -- Master/Branch License Type Candidate
                    IF c_1.branchapplies = 'Y' THEN
                        FOR b_1
                            IN (SELECT toobjectid masterltobjid,
                                       relationshipid
                                  FROM api.relationships
                                 WHERE fromobjectid = c_1.prilictypeobjid
                                   AND endpointid = t_pltmasterepid)
                        LOOP
                            -- Remove rel from PLT to LT
                            api.pkg_columnupdate.setvalue(
                                c_1.prilictypeobjid,
                                'IsBranchS',
                                'Y');
                            -- Relate the Branch to the Master
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    t_ltmasterepid,
                                    t_lictypejobobjid,
                                    b_1.masterltobjid);
                            --Set the ExpirationDate of the new Branch LT to the ExpirationDate of it's Master LT
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringMonth',
                                api.pkg_columnquery.VALUE(b_1.masterltobjid,
                                                          'ExpiringMonth'));
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringYear',
                                api.pkg_columnquery.VALUE(b_1.masterltobjid,
                                                          'ExpiringYear'));
                            api.pkg_relationshipupdate.remove(
                                b_1.relationshipid);
                        END LOOP;

                        --get the relationship of when the issuing PLT is related to a Master PLT  Copy it over and remove the previous rel from the original Branch PLT to the Master PLT
                        FOR b_2
                            IN (SELECT r.toobjectid     masterplt,
                                       r.relationshipid tomasterrelid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = c_1.prilictypeobjid
                                   AND r.endpointid = t_pltbranchtomasterepid)
                        LOOP
                            --Create the new relationship from the Branch j_LicenseType to the Master PLT
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    t_ltmasterbranchepid,
                                    t_lictypejobobjid,
                                    b_2.masterplt);
                            --remove the relationship from the previous Branch PLT to the Master PLT
                            api.pkg_relationshipupdate.remove(
                                b_2.tomasterrelid);
                            api.pkg_columnupdate.setvalue(
                                c_1.prilictypeobjid,
                                'IsBranchS',
                                'Y');
                        END LOOP;             --to Master Primary License Type

                        --get the relationship of when the issuing PLT is related to a Branch PLT  Copy it over and remove the previous rel from the original Master PLT to the Branch PLT
                        FOR b_3
                            IN (SELECT r.toobjectid branchplt,
                                       r.relationshipid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = c_1.prilictypeobjid
                                   AND r.endpointid = t_pltmastertobranchepid)
                        LOOP
                            --Create the new relationship from the Master j_LicenseType to the Branch PLT
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    t_ltprimbranchepid,
                                    t_lictypejobobjid,
                                    b_3.branchplt);
                            --remove the relationship from the previous Branch PLT to the Master PLT
                            api.pkg_relationshipupdate.remove(
                                b_3.relationshipid);
                        END LOOP;             --to Master Primary License Type

                        ------+++++ PLT is a Master of a Branch License Type
                        FOR b_4
                            IN (SELECT toobjectid masterltobjid,
                                       relationshipid
                                  FROM api.relationships
                                 WHERE fromobjectid = c_1.prilictypeobjid
                                   AND endpointid = t_pltmasterprimltepid)
                        LOOP
                            -- Remove rel from PLT to LT
                            api.pkg_relationshipupdate.remove(
                                b_4.relationshipid);
                            -- Relate the Branch to the Master
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    t_ltbranchltepid,
                                    t_lictypejobobjid,
                                    b_4.masterltobjid);
                            --Set the ExpirationDate of the new Branch LT to the ExpirationDate of it's Master LT
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringMonth',
                                api.pkg_columnquery.VALUE(b_4.masterltobjid,
                                                          'ExpiringMonth'));
                            api.pkg_columnupdate.setvalue(
                                t_lictypejobobjid,
                                'ExpiringYear',
                                api.pkg_columnquery.VALUE(b_4.masterltobjid,
                                                          'ExpiringYear'));
                        END LOOP;
                    ------+++++
                    END IF;            -- Master/Branch License Type Candidate

                    BEGIN --Now look at the app again for possible Secondary License Types for this Primary
                        FOR c_3
                            IN (SELECT DISTINCT
                                       slt.toobjectid     ltcsecobjid,
                                       slt.relationshipid apprelpltsecltc,
                                       r2.toobjectid      issseccatrelid
                                  FROM api.relationships  slt
                                       LEFT OUTER JOIN api.relationships r1
                                           ON r1.toobjectid = slt.toobjectid --
                                          AND r1.endpointid =
                                              t_psltendpointid
                                       LEFT OUTER JOIN api.relationships r2
                                           ON r2.toobjectid = r1.fromobjectid
                                          AND r2.endpointid = t_pltendpointid
                                          AND r2.fromobjectid =
                                              slt.fromobjectid
                                       LEFT OUTER JOIN
                                       query.r_issuelicenseplt iplt
                                           ON iplt.primarylicensetypeobjectid =
                                              slt.fromobjectid
                                          AND iplt.issuelicenseprocessid =
                                              a_processobjid
                                 WHERE slt.fromobjectid = c_1.prilictypeobjid
                                   AND slt.endpointid =
                                       t_pltlictypecatsecepid
                                   AND (api.pkg_columnquery.VALUE(
                                            r2.fromobjectid,
                                            'Issue') =
                                        'Y'
                                     OR api.pkg_columnquery.VALUE(
                                            iplt.issuelicenseprocessid,
                                            'IssueAllLicenseTypes') =
                                        'Y')
                                   AND api.pkg_columnquery.VALUE(
                                           slt.relationshipid,
                                           'SStatus') NOT IN
                                           (SELECT UPPER(s.description)
                                              FROM api.statuses  s
                                                   JOIN api.jobstatuses js
                                                       ON js.statusid =
                                                          s.statusid
                                                      AND js.jobtypeid =
                                                          t_lictypedefid
                                             WHERE js.statustype IN
                                                       ('C', 'X'))
                                   AND r2.toobjectid IS NOT NULL)
                        LOOP
                            -- Set the Issued Boolean when the SLT is included in the Issue process.
                            api.pkg_columnupdate.setvalue(
                                c_3.apprelpltsecltc,
                                'Issued',
                                'Y');
                            api.pkg_columnupdate.setvalue(
                                c_3.apprelpltsecltc,
                                'SStatus',
                                'ISSUED');

                            IF c_3.issseccatrelid IS NOT NULL THEN
                                api.pkg_columnupdate.setvalue(
                                    c_3.issseccatrelid,
                                    'Status',
                                    'ISSUED');
                            END IF;

                            --api.pkg_columnupdate.setvalue(c_3.Issseccatrelid, 'Status', 'ISSUED');

                            -- Relate this Secondary License Type to the Primary License Type on the License
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    t_lictypecatsecepid,
                                    t_lictypejobobjid,
                                    c_3.ltcsecobjid);
                            -- Set the Status Date and Status on new Secondary License Types.
                            t_statusdate   :=
                                api.pkg_columnquery.datevalue(
                                    c_3.apprelpltsecltc,
                                    'StatusDate');
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'StatusDate',
                                                          t_statusdate);
                            -- Copy License Type Count for the Secondary License Type
                            pkg_copy.copystoredobjectdetails(
                                c_3.apprelpltsecltc,
                                t_newrelobjectid);
                            -- Set the Status Date and Status on new Secondary License Types.
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'Status',
                                                          'PENDING');
                            -- Set the batch flags on the secondary license types
                            pkg_batchtype.setbatchflags(
                                t_newrelobjectid,
                                a_includeinproducelicensebatch => 'Y',
                                a_includeindailybatch => 'Y');
                            -- Set the Ready to Issue Date on the secondary license types
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'ReadyToIssueDate',
                                                          t_readytoissuedate);
                            -- Set the type of issueance on the secondary license types
                            api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                          'TypeOfIssuance',
                                                          c_1.typeofissuance);

                            --Duplicates
                            FOR c_dup
                                IN (SELECT d.duplicateid objectid,
                                           d.licensetypecategoryobjectid,
                                           d.description
                                      FROM sitespecific.duplicate_t d
                                     WHERE d.primarylicensetypeobjectid =
                                           c_1.prilictypeobjid
                                       AND d.licensetypecategoryobjectid =
                                           c_3.ltcsecobjid)
                            LOOP
                                --api.pkg_errors.RaiseError(-20001, 'BA Debugging - c_1.PriLicTypeObjId: ' || c_1.PriLicTypeObjId || ' c_3.LTCSecObjId: ' || c_3.LTCSecObjId); --BA DEBUGGING
                                --Create new duplicates on License Type
                                t_newobjectid   :=
                                    api.pkg_objectupdate.new(
                                        api.pkg_configquery.objectdefidforname(
                                            'o_Duplicate'));

                                --  Copy the Duplicate Details
                                --note that it is important to set the license type category object id before anything else otherwise it errors.
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'LicenseTypeCategoryObjectID',
                                    c_dup.licensetypecategoryobjectid);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'Description',
                                    c_dup.description);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'LicenseTypeJobID',
                                    t_lictypejobobjid);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'RelationshipId',
                                    t_newrelobjectid);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'ReadyToIssueDate',
                                    t_readytoissuedate);
                                api.pkg_columnupdate.setvalue(
                                    t_newobjectid,
                                    'TypeOfIssuance',
                                    c_1.typeofissuance);
                                api.pkg_columnupdate.setvalue(t_newobjectid,
                                                              'IssueDate',
                                                              SYSDATE);
                                pkg_copy.copystoredobjectdetails(
                                    c_dup.objectid,
                                    t_newobjectid);
                                api.pkg_columnupdate.removevalue(
                                    t_newobjectid,
                                    'BatchDate'); -- Gurpreet -- Issue # 2528 (ABC# 1915) ; Dup on Transfers Apps were not printing or earning in Daily Batch. Print Flag was not being updated, In PKG_BatchType.ProduceLicenses (if (dup_l.batchdate is null and t_DailyorRenewal = 'Daily'))
                            END LOOP;
                        END LOOP;          -- c_3  Secondaries off new Primary

                        --Mantain Dups on post verify
                        api.pkg_columnupdate.setvalue(
                            t_lictypejobobjid,
                            'dup_IncludeInProduceLicBatchSe',
                            'Y');
                    EXCEPTION
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'ERROR relating New Secondary LT with New Primary License Type:'
                                || c_1.licensetypecode
                                || SQLERRM);
                    END;
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'ERROR with Primary License Type:'
                        || c_1.licensetypecode
                        || SQLERRM);
            END;
        END LOOP; -- c_1 Primary License Types on Application temporary placement

        -- SEE IF ANY PRIMARY OR SECONDARY LICENSE TYPE SHOULD BE REMOVED FROM THE LICENSE
        -- If it is not on the Application, then remove it from License.
        -- Grab Primary License Types (PLT) associated with the License which are not in status 'CANCEL'
        FOR c_4
            IN (SELECT r1.toobjectid prilictypeobjid,
                       r2.toobjectid ltcobjid,
                       ltc.licensetypecode -- Only using this for Error messages
                  FROM api.relationships  r1
                       JOIN api.relationships r2
                           ON r2.fromobjectid = r1.toobjectid
                          AND r2.endpointid = t_lictypecatprimepid
                       JOIN query.o_licensetypecategory ltc
                           ON ltc.objectid = r2.toobjectid
                       JOIN query.j_licensetype lt
                           ON lt.objectid = r1.toobjectid
                       JOIN api.jobstatuses js
                           ON js.jobtypeid = lt.jobtypeid
                          AND js.statusid = lt.statusid
                          AND js.statustype NOT IN ('C', 'X') --issue 943 --and lt.StatusName <> 'CANCEL'
                 WHERE r1.fromobjectid = t_chnglicobjid
                   AND r1.endpointid = t_licltepid)
        LOOP
            BEGIN -- Is this Primary License Type on the Application?  If not, cancel it from License.
                SELECT r1.toobjectid, r1.fromobjectid
                  INTO t_liclictypcatpriobjid, t_licpltobjid
                  FROM query.o_licensetypecategory  ltc
                       JOIN api.relationships r1
                           ON r1.toobjectid = ltc.objectid
                          AND r1.endpointid = t_pltlictypecatepid
                       JOIN api.relationships r2
                           ON r2.toobjectid = r1.fromobjectid
                          AND r2.endpointid = t_apppltepid
                 WHERE r2.fromobjectid = a_appobjectid
                   AND r1.toobjectid = c_4.ltcobjid;

                -- If code comes here the Primary on the License is on the Application,
                -- and therefore should remain on the License.
                -- Now evaluate this Primary on the License for any Secondaries.
                -- Each Secondary on the License must be on App; otherwise remove it from License.
                -- Update License Type Count for the Secondary, if Secondary is to remain on License.
                FOR c_5
                    IN (SELECT r1.toobjectid     ltcsecobjid,
                               r1.fromobjectid   priltobjid,
                               r1.relationshipid secrelid
                          FROM api.relationships  r1
                               JOIN api.relationships r2
                                   ON r2.toobjectid = r1.toobjectid
                                  AND r2.endpointid = t_psltendpointid
                               JOIN api.relationships r3
                                   ON r3.toobjectid = r2.fromobjectid
                                  AND r3.endpointid = t_pltendpointid
                               JOIN query.r_issuelicenseplt iplt
                                   ON iplt.primarylicensetypeobjectid =
                                      r3.toobjectid
                                  AND iplt.issuelicenseprocessid =
                                      a_processobjid
                                  AND iplt.primarylicensetypeobjectid =
                                      r3.fromobjectid
                         WHERE r1.fromobjectid = c_4.prilictypeobjid
                           AND r1.endpointid = t_lictypecatsecepid
                           AND (api.pkg_columnquery.VALUE(r2.fromobjectid,
                                                          'Issue') =
                                'Y'
                             OR api.pkg_columnquery.VALUE(
                                    iplt.issuelicenseprocessid,
                                    'IssueAllLicenseTypes') =
                                'Y'))
                LOOP
                    BEGIN -- Is this Secondary on the Application?  If not, remove it from License
                        SELECT r1.toobjectid, r1.relationshipid
                          INTO t_ltcsecobjid, t_apprelpltsecltc
                          FROM api.relationships  r1
                               JOIN api.relationships r2
                                   ON r2.toobjectid = r1.fromobjectid
                                  AND r2.endpointid = t_apppltepid
                         WHERE r2.fromobjectid = a_appobjectid
                           AND r1.toobjectid = c_5.ltcsecobjid
                           AND r1.endpointid = t_pltlictypecatsecepid;

                        -- Copy License Type Count for the Secondary License Type, in case the count was changed by the Application
                        pkg_copy.copystoredobjectdetails(t_apprelpltsecltc,
                                                         c_5.secrelid);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN -- Remove Relationship to this Secondary License Type
                            api.pkg_relationshipupdate.remove(c_5.secrelid);
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'ERROR removing Secondary License Type: '
                                || SQLERRM);
                    END;
                END LOOP;               -- c_5 Existing Secondaries on License
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'ERROR with Primary License Type:'
                        || c_4.licensetypecode
                        || SQLERRM);
            END;
        END LOOP;                      -- c_4 Primary License Types on License

        --Issue any Secondary LTs for Existing License Types.
        sitespecific.pkg_issuelicense.issueslt(a_processobjid, a_appobjectid);

        IF t_lastissuelicenseprocess = 'Y' THEN
            FOR plt
                IN (SELECT r.licensetypeobjectid
                               prilictypeobjid,
                           api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                                     'LicenseTypeCode')
                               ltcode
                      FROM query.r_appprimarylicensetype r
                     WHERE r.applicationobjectid = a_appobjectid
                       AND api.pkg_columnquery.VALUE(r.licensetypeobjectid,
                                                     'Status') NOT IN
                               (SELECT UPPER(s.description)
                                  FROM api.statuses  s
                                       JOIN api.jobstatuses js
                                           ON js.statusid = s.statusid
                                          AND js.jobtypeid = t_lictypedefid
                                 WHERE js.statustype IN ('C', 'X')))
            LOOP
                FOR inv
                    IN (SELECT ai.relationshipid   appinvrelid,
                               ai.investigationjobid,
                               iplt.relationshipid applicpltrelid,
                               iplt.primarylicensetypejobid
                          FROM query.r_applicationinvestigation  ai
                               JOIN query.r_investigationprilicensetype iplt
                                   ON iplt.investigationjobid =
                                      ai.investigationjobid
                         WHERE iplt.primarylicensetypejobid =
                               plt.prilictypeobjid)
                LOOP
                    --Move from the Application and Primary License Type
                    api.pkg_relationshipupdate.remove(inv.appinvrelid,
                                                      SYSDATE);
                    api.pkg_relationshipupdate.remove(inv.applicpltrelid,
                                                      SYSDATE);
                    --To the New License and New License Type
                    t_investigationrel   :=
                        api.pkg_relationshipupdate.new(
                            t_investlicepid,
                            inv.investigationjobid,
                            t_chnglicobjid);

                    BEGIN
                        SELECT llt.licensetypejobid
                          INTO t_lictypejobobjid
                          FROM query.r_licenselicensetype llt
                         WHERE llt.licensejobid = t_chnglicobjid
                           AND api.pkg_columnquery.VALUE(
                                   llt.licensetypejobid,
                                   'LicenseTypeCode') =
                               plt.ltcode;

                        t_applicableltinvrelid   :=
                            api.pkg_relationshipupdate.new(
                                t_investltepid,
                                inv.investigationjobid,
                                t_lictypejobobjid);
                    EXCEPTION
                        WHEN OTHERS THEN
                            api.pkg_errors.raiseerror(
                                -20000,
                                   'Investigation Move Fail: Error Relating the Investigation to a License Type. '
                                || SQLERRM);
                    END;
                END LOOP;
            END LOOP;                                              -- PLT Loop

            -- Find all related Investigations that was not related a the Primary License Type
            -- then move it to the new License.
            FOR inv2 IN (SELECT ai.relationshipid, ai.investigationjobid
                           FROM query.r_applicationinvestigation ai
                          WHERE ai.applicationjobid = a_appobjectid)
            LOOP
                -- Move from the Application
                api.pkg_relationshipupdate.remove(inv2.relationshipid,
                                                  SYSDATE);
                -- To the New License
                t_investigationrel   :=
                    api.pkg_relationshipupdate.new(t_investlicepid,
                                                   inv2.investigationjobid,
                                                   t_chnglicobjid);
            END LOOP;
        END IF;

        -- If the License already exists, remove the existing conditions before relating the current ones from the Application
        FOR c IN (SELECT r.relationshipid
                    FROM query.r_licensecondition r
                   WHERE r.licensejobid = t_chnglicobjid
                  UNION
                  SELECT a.relationshipid
                    FROM query.r_licenseadditioncondition a
                   WHERE a.licensejobid = t_chnglicobjid)
        LOOP
            api.pkg_relationshipupdate.remove(c.relationshipid);
        END LOOP;

        -- Copy Conditions to License
        t_endpointid   :=
            api.pkg_configquery.endpointidforname('j_License', 'Condition');

        FOR c IN (SELECT *
                    FROM query.r_applicationcondition r
                   WHERE r.applicationjobid = a_appobjectid)
        LOOP
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_chnglicobjid,
                                               c.conditionobjectid);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'DetailsCopied',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionText',
                                          c.conditiontext);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionCode',
                                          c.conditioncode);
            api.pkg_columnupdate.setvalue(t_relationshipid,
                                          'ConditionRelCount',
                                          c.conditionrelcount);
            api.pkg_columnupdate.setvalue(t_relationshipid, 'Sort', c.sort);
        END LOOP;

        -- Copy Additional Conditions to License
        t_endpointid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'AdditCondition');
        t_objectdefid   :=
            api.pkg_configquery.objectdefidforname('o_AdditionalCondition');

        FOR x
            IN (SELECT ac.objectid, ac.sort2, ac.conditiontext
                  FROM query.r_applicationadditioncondition  r
                       JOIN query.o_additionalcondition ac
                           ON ac.objectid = r.additionalconditionobjectid
                 WHERE r.applicationjobid = a_appobjectid)
        LOOP
            t_newobjectid   := api.pkg_objectupdate.new(t_objectdefid);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'ConditionText',
                                          x.conditiontext);
            api.pkg_columnupdate.setvalue(t_newobjectid, 'Sort2', x.sort2);
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_chnglicobjid,
                                               t_newobjectid);
        END LOOP;
    END issuechangelicense;                                -- end of Procedure

    PROCEDURE issueoneday(a_objectid udt_id, a_asofdate DATE)
    IS
        t_paymentid       udt_id;
        t_processid       udt_id;
        t_processtypeid   udt_id;
    BEGIN
        t_paymentid   :=
            api.pkg_columnquery.numericvalue(a_objectid, 'PaymentId');
        t_processtypeid   :=
            api.pkg_configquery.objectdefidforname('p_IssueOneDayLicense');

        -- RyanL: Changed the fee calculation for performance (PIP Task 8.5)
        FOR i
            IN (  SELECT j.jobid
                    FROM api.payments p
                         JOIN api.paymenttransactions pt
                             ON pt.paymentid = p.paymentid
                         JOIN api.feetransactions ft
                             ON ft.transactionid = pt.transactionid
                         JOIN api.fees f ON f.feeid = ft.feeid
                         JOIN api.jobs j
                             ON j.jobid = f.jobid
                            AND j.jobtypeid =
                                api.pkg_configquery.objectdefidforname(
                                    'j_OneDayLicense')
                   WHERE p.paymentid = t_paymentid
                     AND NOT EXISTS
                             (SELECT 1
                                FROM api.fees x
                               WHERE x.jobid = j.jobid
                                 AND (  x.amount
                                      + NVL((SELECT SUM(amount)
                                               FROM api.feetransactions ft
                                              WHERE ft.feeid = x.feeid),
                                            0)) > 0)
                     AND j.statusid = (SELECT s.statusid
                                         FROM api.statuses s
                                        WHERE s.tag = 'RDISSU')
                GROUP BY j.jobid)
        LOOP
            t_processid   :=
                api.pkg_processupdate.new(i.jobid,
                                          t_processtypeid,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            api.pkg_processupdate.complete(t_processid, 'Issue');
        END LOOP;
    END issueoneday;

    /*----------------------------------------------------------------------------------------------
    --  FillLicenseTypesGrid()     --Public
    --  Populates the License Types grid on the Issue License process.
    ----------------------------------------------------------------------------------------------*/

    PROCEDURE filllicensetypesgrid(a_objectid udt_id, a_asofdate DATE)
    IS
        t_jobid                     udt_id := api.pkg_columnquery.VALUE(a_objectid, 'Jobid');
        t_objectdefname             VARCHAR2(30)
            := api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName');
        t_newobjdefid               udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_PendingSecondaryLicenseType');
        t_newrelid                  udt_id;
        t_newobjid                  udt_id;
        t_objectdefnameiswithdraw   VARCHAR2(1);
    BEGIN
        -- when a user relates two of the same secondary type under two primaries raise an error.
        IF t_objectdefname = 'p_WithdrawApplication' THEN
            t_objectdefnameiswithdraw   := 'Y';
        END IF;

        /*Issue 2113 removed this error.
        if api.pkg_columnquery.value(t_Jobid, 'DupSecLTError') > 0 then
          api.pkg_errors.RaiseError(-20000, 'You cannot have the same Secondary License Type on multiple Primary License Types.');
        end if;*/
        BEGIN
            FOR c
                IN (SELECT 'PrimaryLicenseType' endpointname,
                           a_objectid           fromobjectid,
                           aplt.toobjectid      toobjectid,
                           NULL                 licensetypecount,
                           NULL                 status,
                           NULL                 masterltcode,
                           NULL                 pltobjectid,
                           NULL                 issued
                      FROM api.relationships aplt
                     WHERE aplt.fromobjectid = t_jobid
                       AND aplt.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'PrimaryLicenseType')
                    /*and api.pkg_columnquery.value(aplt.ToObjectId, 'Status') not in
                      (select upper(s.Description)
                         from api.statuses s
                         join api.jobstatuses js
                           on js.StatusId = s.StatusId
                           and js.JobTypeId = api.pkg_configquery.ObjectDefIdForName('j_Application')
                        where js.StatusType in ('C', 'X'))*/
                    UNION ALL
                    SELECT 'PendSecLicType'
                               endpointname,
                           slt.fromobjectid
                               fromobjectid,
                           slt.toobjectid
                               toobjectid,
                           api.pkg_columnquery.VALUE(slt.relationshipid,
                                                     'LicenseTypeCount')
                               licensetypecount,
                           api.pkg_columnquery.VALUE(slt.relationshipid,
                                                     'SStatus')
                               status,
                           api.pkg_columnquery.VALUE(aplt.toobjectid,
                                                     'LicenseTypeCode')
                               masterltcode,
                           aplt.toobjectid
                               pltobjectid,
                           api.pkg_columnquery.VALUE(slt.relationshipid,
                                                     'Issued')
                               issued
                      FROM api.relationships  aplt
                           JOIN api.relationships slt
                               ON slt.fromobjectid = aplt.toobjectid
                              AND slt.endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'o_PrimaryLicenseType',
                                      'LicTypeCatSecondary')
                     WHERE aplt.fromobjectid = t_jobid
                       AND aplt.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'PrimaryLicenseType')
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM api.relationships  r
                                       JOIN api.relationships r2
                                           ON r2.fromobjectid = r.toobjectid
                                          AND r2.endpointid =
                                              api.pkg_configquery.endpointidforname(
                                                  'o_PendingSecondaryLicenseType',
                                                  'PendLicTypeCatSecondary')
                                 WHERE r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_PrimaryLicenseType',
                                           'PendSecLicType')
                                   AND r.fromobjectid = slt.fromobjectid
                                   AND r2.toobjectid = slt.toobjectid) /*and api.pkg_columnquery.value(slt.RelationshipId, 'SStatus') not in
                                                                       (select upper(s.Description)
                                                                           from api.statuses s
                                                                           join api.jobstatuses js
                                                                             on js.StatusId = s.StatusId
                                                                             and js.JobTypeId = api.pkg_configquery.ObjectDefIdForName('j_Application')
                                                                          where js.StatusType in ('C', 'X'))*/
                                                                      )
            LOOP
                --When Secondary create new object
                IF c.endpointname = 'PendSecLicType' THEN
                    t_newobjid        := api.pkg_objectupdate.new(t_newobjdefid);
                    t_newrelid        :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'o_PendingSecondaryLicenseType',
                                'PendLicTypeCatSecondary'),
                            t_newobjid,
                            c.toobjectid);
                    t_objectdefname   := 'o_PrimaryLicenseType';
                ELSIF t_objectdefnameiswithdraw = 'Y' THEN
                    t_newobjid        := NULL;
                    t_objectdefname   := 'p_WithdrawApplication';
                ELSE
                    t_newobjid        := NULL;
                    t_objectdefname   := 'p_IssueLicense';
                END IF;

                t_newrelid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            t_objectdefname,
                            c.endpointname),                --'p_IssueLicense'
                        c.fromobjectid,
                        NVL(t_newobjid, c.toobjectid));

                IF c.licensetypecount IS NOT NULL THEN
                    api.pkg_columnupdate.setvalue(t_newobjid,
                                                  'LicenseTypeCount',
                                                  c.licensetypecount);
                END IF;

                IF c.status IS NOT NULL THEN
                    api.pkg_columnupdate.setvalue(t_newobjid,
                                                  'Status',
                                                  c.status);
                END IF;

                IF c.masterltcode IS NOT NULL THEN
                    api.pkg_columnupdate.setvalue(t_newobjid,
                                                  'MasterLTCode',
                                                  c.masterltcode);
                END IF;

                IF c.pltobjectid IS NOT NULL THEN
                    api.pkg_columnupdate.setvalue(t_newobjid,
                                                  'Issued',
                                                  c.issued);
                END IF;
            END LOOP;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN OTHERS THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'Error relating License Type: ' || SQLERRM);
        END;
    END filllicensetypesgrid;

    /*----------------------------------------------------------------------------------------------------
      --  IssueSLTs()     --Public
      --  This procedure is called within the Issue procedures and will issue only the secondary LTs
      -- when and only when the primary is issued and the SLT has the issue check box flagged.
      ----------------------------------------------------------------------------------------------------*/

    PROCEDURE issueslt(a_issueprocessid udt_id, a_jobid udt_id)
    IS
        t_newrelobjectid    udt_id;
        t_lictypejobobjid   udt_id;
        t_r2idate           DATE;
        t_sltexists         VARCHAR2(1);
        t_sltrelid          udt_id;
        t_fromslt           udt_id;
        t_typeofissuance    VARCHAR2(40);
    BEGIN
        t_r2idate   :=
            api.pkg_columnquery.datevalue(a_issueprocessid,
                                          'ReadytoIssueDate');

        FOR c
            IN ( /*select slt.LicenseTypeCategoryObjectId SecLTObjId,
                        slt.LicenseTypeCount,
                        slt.RelationshipId,
                        slt.PrimaryLicenseTypeObjectId
                 from query.r_PriLTLTCatSecondary slt
                 join query.r_IssueLicenseLTCatSecondary islt on islt.MasterLTObjectId = slt.PrimaryLicenseTypeObjectId
                                                              and islt.LicenseTypeCategoryObjectId = slt.LicenseTypeCategoryObjectId
                where islt.IssueLicenseProcessId = a_IssueProcessId
                  and (islt.Issue = 'Y'
                   or api.pkg_columnquery.value(islt.IssueLicenseProcessId,'IssueAllLicenseTypes')= 'Y')
                  and slt.Issued = 'N'*/
                SELECT sltc.toobjectid
                           secltobjid,
                       api.pkg_columnquery.VALUE(islt.toobjectid,
                                                 'LicenseTypeCount')
                           licensetypecount,
                       slt.relationshipid,
                       slt.fromobjectid
                           primarylicensetypeobjectid,
                       islt.toobjectid
                           pendsecltobjid,
                       api.pkg_columnquery.VALUE(slt.relationshipid,
                                                 'IsTransferred')
                           istransferred
                  FROM api.relationships  plt
                       JOIN api.relationships islt
                           ON islt.fromobjectid = plt.toobjectid
                          AND islt.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'o_PrimaryLicenseType',
                                  'PendSecLicType')
                       JOIN api.relationships sltc
                           ON sltc.fromobjectid = islt.toobjectid
                          AND sltc.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'o_PendingSecondaryLicenseType',
                                  'PendLicTypeCatSecondary')
                       JOIN api.relationships slt
                           ON slt.fromobjectid = plt.toobjectid
                          AND slt.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'o_PrimaryLicenseType',
                                  'LicTypeCatSecondary')
                          AND slt.toobjectid = sltc.toobjectid
                 WHERE plt.fromobjectid = a_issueprocessid
                   AND plt.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'p_IssueLicense',
                           'PrimaryLicenseType')
                   AND (api.pkg_columnquery.VALUE(islt.toobjectid, 'Issue') =
                        'Y'
                     OR api.pkg_columnquery.VALUE(plt.fromobjectid,
                                                  'IssueAllLicenseTypes') =
                        'Y')
                   AND api.pkg_columnquery.VALUE(slt.relationshipid,
                                                 'Issued') =
                       'N'
                   AND api.pkg_columnquery.VALUE(slt.relationshipid,
                                                 'SStatus') NOT IN
                           (SELECT UPPER(s.description)
                              FROM api.statuses  s
                                   JOIN api.jobstatuses js
                                       ON js.statusid = s.statusid
                                      AND js.jobtypeid =
                                          api.pkg_configquery.objectdefidforname(
                                              'j_LicenseType')
                             WHERE js.statustype IN ('C', 'X')))
        LOOP
            SELECT liclt.licensetypejobid,
                   NVL2(slt.relationshipid, 'Y', 'N') sltexists,
                   slt.relationshipid
              INTO t_lictypejobobjid, t_sltexists, t_sltrelid
              FROM query.r_applicationlicense  al
                   JOIN query.r_licenselicensetype liclt
                       ON liclt.licensejobid = al.licensejobid
                   LEFT OUTER JOIN query.r_licensetypeltcatsecondary slt
                       ON slt.licensetypejobid = liclt.licensetypejobid
                      AND slt.licensetypecategoryobjectid = c.secltobjid
             WHERE al.applicationjobid = a_jobid
               AND api.pkg_columnquery.VALUE(liclt.licensetypejobid,
                                             'LicenseTypeCode') =
                   api.pkg_columnquery.VALUE(c.primarylicensetypeobjectid,
                                             'LicenseTypeCode');

            -- Set the Issued Boolean when the SLT is included in the Issue process.
            api.pkg_columnupdate.setvalue(c.relationshipid, 'Issued', 'Y');
            api.pkg_columnupdate.setvalue(c.pendsecltobjid, 'Issued', 'Y');
            api.pkg_columnupdate.setvalue(c.relationshipid,
                                          'SStatus',
                                          'ISSUED');
            api.pkg_columnupdate.setvalue(c.pendsecltobjid,
                                          'Status',
                                          'ISSUED');


            -- if this is a change application then skip creating the relationship when it exists.
            IF t_sltexists = 'N' THEN
                -- Relate the License Type Category to the License Type Job, to represent a Secondary License Type
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_LicenseType',
                            'LicTypeCatSecondary'),
                        t_lictypejobobjid,
                        c.secltobjid);

                -- Set the Status date on the Secondary License Types
                api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                              'StatusDate',
                                              SYSDATE);


                -- Copy License Type Count for the Secondary License Type
                pkg_copy.copystoredobjectdetails(c.relationshipid,
                                                 t_newrelobjectid);

                -- Set the Status Date and Status on the New License Type
                api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                              'Status',
                                              'PENDING');

                -- Set the batch flags
                pkg_batchtype.setbatchflags(
                    t_newrelobjectid,            --Added for Hotfix22 Part One
                    a_includeinproducelicensebatch => 'Y',
                    a_includeindailybatch => 'Y');

                -- Set the Status Date and Status on the New License Type
                api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                              'TypeOfIssuance',
                                              'DOR'); --Added for Hotfix22 Part One

                -- Set the Ready to Issue Date
                api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                              'ReadyToIssueDate',
                                              t_r2idate); --Added for Hotfix22 Part One

                -- Maintain dups on post verify
                api.pkg_columnupdate.setvalue(
                    t_lictypejobobjid,
                    'dup_IncludeInProduceLicBatchSe',
                    'Y');                        --Added for Hotfix22 Part One

                FOR c_dup
                    IN (SELECT d.duplicateid objectid
                          FROM sitespecific.duplicate_t d
                         WHERE d.primarylicensetypeobjectid =
                               c.primarylicensetypeobjectid
                           AND d.licensetypecategoryobjectid = c.secltobjid)
                LOOP
                    --Copy duplicate objects to License Type by setting the License Type Job ID
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'LicenseTypeJobId',
                                                  t_lictypejobobjid);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'RelationshipID',
                                                  t_newrelobjectid);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'IssueDate',
                                                  SYSDATE);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'ReadyToIssueDate',
                                                  t_r2idate);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'TypeOfIssuance',
                                                  'DOR');
                END LOOP;
            ELSIF t_sltexists = 'Y' THEN
                -- Copy License Type Count for the Secondary License Type
                pkg_copy.copystoredobjectdetails(c.relationshipid,
                                                 t_sltrelid);

                -- Set the batch flags
                pkg_batchtype.setbatchflags(
                    t_sltrelid,                  --Added for Hotfix22 Part One
                    a_includeinproducelicensebatch => 'Y',
                    a_includeindailybatch => 'Y');

                -- Set the Ready to Issue Date
                api.pkg_columnupdate.setvalue(t_sltrelid,
                                              'ReadyToIssueDate',
                                              t_r2idate); --Added for Hotfix22 Part One

                -- Maintain dups on post verify
                api.pkg_columnupdate.setvalue(
                    t_lictypejobobjid,
                    'dup_IncludeInProduceLicBatchSe',
                    'Y');                        --Added for Hotfix22 Part One

                -- Set the type of issueance on the secondary license types
                SELECT pls.fromslt
                  INTO t_fromslt
                  FROM query.r_priltltcatsecondary pls
                 WHERE pls.primarylicensetypeobjectid = t_sltrelid;

                t_typeofissuance   :=
                    api.pkg_columnquery.VALUE(c.primarylicensetypeobjectid,
                                              'TypeOfIssuance');

                IF c.istransferred = 'N' THEN
                    api.pkg_columnupdate.setvalue(t_sltrelid,
                                                  'TypeOfIssuance',
                                                  t_typeofissuance); --Hotfix22 Part One
                ELSIF c.istransferred = 'Y' THEN
                    SELECT REGEXP_REPLACE(t_typeofissuance,
                                          '[[:digit:]]{2}',
                                          t_fromslt,
                                          1,
                                          1)
                      INTO t_sectypeofissuance
                      FROM DUAL;

                    api.pkg_columnupdate.setvalue(t_sltrelid,
                                                  'TypeOfIssuance',
                                                  t_sectypeofissuance);
                END IF;

                --api.pkg_columnupdate.SetValue(t_SLTRelId,'TypeOfIssuance', api.pkg_columnquery.value(c.primarylicensetypeobjectid, 'TypeOfIssuance'));        --Hotfix22 Part One

                FOR c_dup
                    IN (SELECT d.duplicateid objectid
                          FROM sitespecific.duplicate_t d
                         WHERE d.primarylicensetypeobjectid =
                               c.primarylicensetypeobjectid
                           AND d.licensetypecategoryobjectid = c.secltobjid)
                LOOP
                    --Copy duplicate objects to License Type by setting the License Type Job ID
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'LicenseTypeJobId',
                                                  t_lictypejobobjid);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'RelationshipID',
                                                  t_sltrelid);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'IssueDate',
                                                  SYSDATE);
                    api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                  'ReadyToIssueDate',
                                                  t_r2idate);

                    IF c.istransferred = 'N' THEN
                        api.pkg_columnupdate.setvalue(
                            c_dup.objectid,
                            'TypeOfIssuance',
                            api.pkg_columnquery.VALUE(
                                c.primarylicensetypeobjectid,
                                'TypeOfIssuance'));
                    ELSIF c.istransferred = 'Y' THEN
                        SELECT REGEXP_REPLACE(t_typeofissuance,
                                              '[[:digit:]]{2}',
                                              t_fromslt,
                                              1,
                                              1)
                          INTO t_sectypeofissuance
                          FROM DUAL;

                        api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                      'TypeOfIssuance',
                                                      t_sectypeofissuance);
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END issueslt;

    /*----------------------------------------------------------------------------------------------------
      --  IssueApp()     --Public
      --  This procedure is called on completion of the Issue Process and if all license types are issued
      -- within the process this procedure will change the status of the Application to Issued.
      ----------------------------------------------------------------------------------------------------*/

    PROCEDURE issueapp(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        t_allltissueb    VARCHAR2(1);
        t_changestatus   udt_id;
    BEGIN
        t_allltissueb   :=
            api.pkg_columnquery.VALUE(a_objectid, 'IsIssueAllLTs');

        IF t_allltissueb = 'Y' THEN
            t_changestatus   :=
                api.pkg_processupdate.new(
                    a_jobid,
                    api.pkg_configquery.objectdefidforname('p_ChangeStatus'),
                    'System Generated.',
                    NULL,
                    NULL,
                    NULL);
            api.pkg_processupdate.complete(t_changestatus, 'Issued');
        END IF;
    END issueapp;

    /***********************
    -- LogLicenseTransfer() PUBLIC
    -- This is to log the issuance of a Transfer or Change
    -- at the License Type level.
    ***********************/

    PROCEDURE loglicensetransfer(a_transtoltjobid VARCHAR2,
                                 a_transtoltcode VARCHAR2,
                                 a_transtolicnum VARCHAR2,
                                 a_pltobjectid   udt_id,
                                 a_appjobid      udt_id)
    IS
        t_applicationtype          VARCHAR2(100);
        t_licensetransfersid       udt_id;
        t_transfromltjobid         udt_id;
        t_transfromltcode          VARCHAR2(3);
        t_transfromlicensenumber   VARCHAR2(40);
    BEGIN
        -- Get Transfer/Change From details
        BEGIN
            SELECT lt.jobid, lt.licensetypecode, lt.licensenumber
              INTO t_transfromltjobid,
                   t_transfromltcode,
                   t_transfromlicensenumber
              FROM query.r_transfromlttoplt  tr
                   JOIN query.j_licensetype lt
                       ON lt.jobid = tr.licensetypejobid
             WHERE tr.primarylicensetypeobjectid = a_pltobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                SELECT lt.jobid, lt.licensetypecode, lt.licensenumber
                  INTO t_transfromltjobid,
                       t_transfromltcode,
                       t_transfromlicensenumber
                  FROM query.r_changelttoplt  tr
                       JOIN query.j_licensetype lt
                           ON lt.jobid = tr.licensetypejobid
                 WHERE tr.primarylicensetypeobjectid = a_pltobjectid;
        END;

        t_applicationtype   :=
            api.pkg_columnquery.VALUE(a_appjobid, 'ApplicationType');

        -- Create new transfer Log object
        t_licensetransfersid   :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('o_LicenseTransfers'));

        -- Assign values to License Transfers details
        api.pkg_columnupdate.setvalue(t_licensetransfersid,
                                      'TransFromLTJobId',
                                      t_transfromltjobid);
        api.pkg_columnupdate.setvalue(t_licensetransfersid,
                                      'TransToLTJobId',
                                      a_transtoltjobid);
        api.pkg_columnupdate.setvalue(t_licensetransfersid,
                                      'TransFromLTCode',
                                      t_transfromltcode);
        api.pkg_columnupdate.setvalue(t_licensetransfersid,
                                      'TransToLTCode',
                                      a_transtoltcode);
        api.pkg_columnupdate.setvalue(t_licensetransfersid,
                                      'TransFromLicenseNumber',
                                      t_transfromlicensenumber);
        api.pkg_columnupdate.setvalue(t_licensetransfersid,
                                      'TransToLicenseNumber',
                                      a_transtolicnum);

        -- Log ActionType
        UPDATE sitespecific.licensetransfers_t
           SET actiontype   =
                   CASE
                       WHEN t_applicationtype = 'Transfer' THEN 'CT'
                       WHEN t_applicationtype = 'Change' THEN 'EX'
                   END
         WHERE objectid = t_licensetransfersid;
    END loglicensetransfer;



    /***********************
    -- ValidatePaymentCheck() PUBLIC
    -- This procedure runs on issuance of a licensetype
    ***********************/
    PROCEDURE validatepaymentcheck(a_processid        udt_id,
                                   a_asofdate         DATE,
                                   a_jobid            udt_id,
                                   a_licensetypecode  VARCHAR2,
                                   a_processpayment   VARCHAR2,
                                   a_continue     OUT VARCHAR2)
    IS
        t_jobids               api.pkg_definition.udt_idlist;
        t_jobname              VARCHAR2(30);
        t_count                NUMBER := 0;
        t_depositdate          DATE;
        t_ltcode               VARCHAR2(3);
        t_paymentobjectdefid   udt_id
            := api.pkg_configquery.objectdefidforname('o_Payment');
    BEGIN
        t_pltendpointid   :=
            api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                  'PendSecLicType');

        SELECT jt.name
          INTO t_jobname
          FROM api.jobs j JOIN api.jobtypes jt ON jt.jobtypeid = j.jobtypeid
         WHERE j.jobid = a_jobid;

        IF t_jobname = 'j_Application'
        OR t_jobname = 'j_LicenseType' THEN
            t_jobids(1)   := a_jobid;
        ELSE
            FOR c IN (SELECT ROWNUM, llt.licensetypejobid
                        FROM query.r_licenselicensetype llt
                       WHERE llt.licensejobid = a_jobid)
            LOOP
                t_jobids(c.ROWNUM)   := c.licensetypejobid;
                t_count              := t_count + 1;
            END LOOP;

            t_jobids(t_count + 1)   := a_jobid;
        END IF;

        FOR e IN 1 .. t_jobids.COUNT
        LOOP
            IF a_processid IS NOT NULL THEN
                FOR f2
                    IN (  SELECT MAX(x.depositdate) depositdate, ltcode, max(paymentmethod) paymentmethod -- 08/05/2021 TJL WO 25899
                            FROM (SELECT CASE
                                             WHEN qp.depositeddate IS NULL --APatterson: PIP Task 8.5
                                                                           THEN
                                                 TO_DATE('12-12-2999',
                                                         'MM-DD-YYYY')
                                             ELSE
                                                 qp.depositeddate
                                         END
                                             depositdate,
                                         (SELECT fs.licensetypecode
                                            FROM sitespecific.feeschedule_t fs
                                           WHERE fs.objectid =
                                                 sitespecific.pkg_fees.getlicfeeschedulobjid(
                                                     f.feeid))
                                             ltcode,
                                     qp.paymentmethod -- 08/05/2021 TJL WO 25899
                                     paymentmethod
                                    FROM api.jobs j
                                         JOIN api.fees f ON f.jobid = j.jobid
                                         JOIN api.feetransactions ft
                                             ON ft.feeid = f.feeid
                                         JOIN api.paymenttransactions pt
                                             ON pt.transactionid =
                                                ft.transactionid
                                         JOIN api.registeredexternalobjects reo
                                             ON reo.linkvalue =
                                                TO_CHAR(pt.paymentid)
                                            AND reo.objectdefid =
                                                t_paymentobjectdefid
                                         JOIN query.o_payment qp
                                             ON qp.objectid = reo.objectid
                                   WHERE j.jobid = t_jobids(e)
                                     AND qp.isdishonored = 'N'
                                     AND qp.isvoidedflag = 'N'
                                     AND qp.isnotrefund = 'Y'
                                     AND qp.paymentamountstored > 0
                                     AND ((qp.depositeddate IS NOT NULL
                                       AND a_processpayment = 'Y')
                                       OR a_processpayment = 'N')
                                     AND EXISTS
                                             (SELECT 1
                                                FROM sitespecific.feeschedule_t
                                                     fs
                                               WHERE fs.objectid =
                                                     sitespecific.pkg_fees.getlicfeeschedulobjid(
                                                         f.feeid))) x
                           WHERE ((ltcode IN
                                       (SELECT lt.licensetypecode
                                          FROM query.p_issuelicense il
                                               JOIN
                                               query.r_issuelicenseplt iplt
                                                   ON iplt.issuelicenseprocessid =
                                                      il.processid
                                               JOIN
                                               query.o_primarylicensetype lt
                                                   ON lt.objectid =
                                                      iplt.primarylicensetypeobjectid
                                         WHERE iplt.issuelicenseprocessid =
                                               a_processid
                                           AND (iplt.issue = 'Y'
                                             OR il.isissuealllts = 'Y')
                                        UNION ALL
                                        SELECT pslt.licensetypecode
                                          FROM query.p_issuelicense il2
                                               JOIN
                                               query.r_issuelicenseplt iplt2
                                                   ON iplt2.issuelicenseprocessid =
                                                      il2.processid
                                               JOIN api.relationships r2
                                                   ON r2.fromobjectid =
                                                      iplt2.primarylicensetypeobjectid
                                                  AND r2.endpointid =
                                                      t_pltendpointid
                                               JOIN
                                               query.o_pendingsecondarylicensetype
                                               pslt
                                                   ON pslt.objectid =
                                                      r2.toobjectid
                                         WHERE iplt2.issuelicenseprocessid =
                                               a_processid
                                           AND (pslt.issue = 'Y'
                                             OR il2.isissuealllts = 'Y'))
                                OR (t_jobname != 'j_Application'))
                              AND a_processpayment = 'N')
                              OR (ltcode = a_licensetypecode
                              AND a_processpayment = 'Y')
                        GROUP BY ltcode)
                LOOP
                    IF f2.depositdate >
                    -- 08/05/2021 TJL WO 25899
                    CASE f2.paymentmethod
                             WHEN 'CRCD' THEN SYSDATE + 1
                             WHEN 'ECHECK' THEN SYSDATE + 1
                             ELSE api.pkg_utils.dateplusworkdays(SYSDATE, -10) end
                   AND a_processpayment = 'N' THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                            'The most recent payment has not been verified, please wait for verification.');
                    ELSIF f2.depositdate =
                          TO_DATE('12-12-2999', 'MM-DD-YYYY')
                      AND a_processpayment = 'Y' THEN
                        a_continue   := 'N';
                    ELSE
                        a_continue   := 'Y';
                    END IF;
                END LOOP;
            ELSE
                FOR f2
                    IN (SELECT MAX(qp.depositeddate) depositdate, max(qp.paymentmethod) paymentmethod -- 08/05/2021 TJL WO 25899
                          FROM api.fees  f
                               JOIN api.feetransactions ft
                                   ON ft.feeid = f.feeid
                               JOIN api.paymenttransactions pt
                                   ON pt.transactionid = ft.transactionid
                               JOIN api.registeredexternalobjects reo
                                   ON reo.linkvalue = TO_CHAR(pt.paymentid)
                                  AND reo.objectdefid = t_paymentobjectdefid
                               JOIN query.o_payment qp
                                   ON qp.objectid = reo.objectid
                         WHERE f.jobid = t_jobids(e)
                           AND qp.isdishonored = 'N'
                           AND qp.isvoidedflag = 'N'
                           AND qp.isnotrefund = 'Y'
                           AND qp.paymentamountstored > 0
                           AND ((qp.depositeddate IS NOT NULL
                             AND a_processpayment = 'Y')
                             OR a_processpayment = 'N')
                           AND EXISTS
                                   (SELECT 1
                                      FROM sitespecific.feeschedule_t fs
                                     WHERE fs.objectid =
                                           sitespecific.pkg_fees.getlicfeeschedulobjid(
                                               f.feeid)
                                       AND fs.licensetypecode =
                                           a_licensetypecode
                                       AND a_processpayment = 'Y'))
                LOOP
                    IF f2.depositdate >
                    -- 08/05/2021 TJL WO 25899
                        CASE f2.paymentmethod
                             WHEN 'CRCD' THEN SYSDATE + 1
                             WHEN 'ECHECK' THEN SYSDATE + 1
                             ELSE api.pkg_utils.dateplusworkdays(SYSDATE, -10) end

                   AND a_processpayment = 'N' THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                            'The most recent payment has not been verified, please wait for verification.');
                    ELSIF f2.depositdate =
                          TO_DATE('12-12-2999', 'MM-DD-YYYY')
                      AND a_processpayment = 'Y' THEN
                        a_continue   := 'N';
                    ELSE
                        a_continue   := 'Y';
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END validatepaymentcheck;

    PROCEDURE validatepaymentcheck(a_processid     udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id)
    IS
        t_continue   VARCHAR2(1);
    BEGIN
        validatepaymentcheck(a_processid,
                             a_asofdate,
                             a_jobid,
                             '',
                             'N',
                             t_continue);
    END validatepaymentcheck;

    PROCEDURE openaccusationserror(a_processid     udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id)
    IS
    BEGIN
        IF api.pkg_columnquery.VALUE(a_jobid, 'RaiseErrOpenAcc') > 0 THEN
            api.pkg_errors.raiseerror(
                -20000,
                'There are open accusations on the transferor that must be closed.');
        END IF;
    END;


    /***********************
    -- DeleteWithdrawApp() PUBLIC
    -- This procedure deletes the incomplete Withdraw Application processes on the Job
    ***********************/
    PROCEDURE deletewithdrawapp(a_objectid      udt_id,
                                a_asofdate      DATE,
                                a_jobid         udt_id)
    IS
    BEGIN
        FOR c IN (SELECT processid
                    FROM query.p_withdrawapplication
                   WHERE jobid = a_jobid
                     AND outcome IS NULL)
        LOOP
            api.pkg_processupdate.remove(c.processid);
        END LOOP;
    END;

    /*********************************************************************************
     * GenIssueCatererEventProcesses() PUBLIC
     * This procedure deletes the incomplete Withdraw Application processes on the Job
     *********************************************************************************/
    PROCEDURE genissuecaterereventprocesses(a_objectid      udt_id,
                                            a_asofdate      DATE,
                                            a_jobid         udt_id,
                                            a_count         NUMBER)
    IS
        t_jobtypename      VARCHAR2(60);
        t_processtypeid    udt_id
            := api.pkg_configquery.objectdefidforname(
                   'p_IssueCatererEventAuth');
        t_processid        udt_id;
        t_relationshipid   udt_id;
        t_endpointid       udt_id
            := api.pkg_configquery.endpointidforname(
                   'o_IssueMultiCatEventPermitAuth',
                   'IssueCatererEventAuthorization');
    BEGIN
        IF a_count IS NULL
        OR a_count < 1 THEN
            api.pkg_errors.raiseerror(
                -20000,
                'Error: Please specify the number of authorizations to generate.');
        END IF;

        BEGIN
            SELECT name
              INTO t_jobtypename
              FROM api.jobs  jo
                   JOIN api.jobtypes jt ON jt.jobtypeid = jo.jobtypeid
             WHERE jo.jobid = NVL(a_jobid, a_objectid);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        IF a_jobid IS NULL
        OR (t_jobtypename != 'j_License'
         OR t_jobtypename IS NULL) THEN
            api.pkg_errors.raiseerror(-20000,
                                      'Error: Please specify a license job.');
        END IF;

        FOR i IN 1 .. a_count
        LOOP
            t_processid   :=
                api.pkg_processupdate.new(a_jobid,
                                          t_processtypeid,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               a_objectid,
                                               t_processid);
        END LOOP;

        api.pkg_columnupdate.removevalue(a_objectid, 'Count');
        api.pkg_columnupdate.removevalue(a_objectid, 'IsAddingRows');
    END;

    /*********************************************************************************
     * IssueMultiCatererEventAuths() PUBLIC
     * This procedure deletes the incomplete Withdraw Application processes on the Job
     *********************************************************************************/
    PROCEDURE issuemulticaterereventauths(a_objectid udt_id, a_asofdate DATE)
    IS
        t_relationshipid                 udt_id;
        t_procconditionalendpointid      udt_id
            := api.pkg_configquery.endpointidforname(
                   'p_IssueCatererEventAuth',
                   'Condition');
        t_procaddconditionalendpointid   udt_id
            := api.pkg_configquery.endpointidforname(
                   'p_IssueCatererEventAuth',
                   'AdditionalCondition');
    BEGIN
        FOR c
            IN (SELECT re.toobjectid processid
                  FROM query.o_issuemulticateventpermitauth  cepa
                       JOIN api.relationships re
                           ON re.fromobjectid = cepa.objectid
                 WHERE re.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'o_IssueMultiCatEventPermitAuth',
                           'IssueCatererEventAuthorization')
                   AND api.pkg_columnquery.VALUE(re.toobjectid, 'Outcome')
                           IS NULL
                   AND cepa.objectid = a_objectid)
        LOOP
            api.pkg_processupdate.complete(c.processid, 'Issue');

            IF api.pkg_columnquery.VALUE(c.processid, 'Conditional') = 'Y' THEN
                FOR d
                    IN (SELECT re.toobjectid conditionobjectid
                          FROM query.o_issuemulticateventpermitauth  cepa
                               JOIN api.relationships re
                                   ON re.fromobjectid = cepa.objectid
                         WHERE re.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_IssueMultiCatEventPermitAuth',
                                   'Condition')
                           AND cepa.objectid = a_objectid)
                LOOP
                    t_relationshipid   :=
                        api.pkg_relationshipupdate.new(
                            t_procconditionalendpointid,
                            c.processid,
                            d.conditionobjectid);
                    pkg_copy.copystoredobjectdetails(d.conditionobjectid,
                                                     t_relationshipid);
                END LOOP;

                FOR d
                    IN (SELECT re.toobjectid addconditionobjectid
                          FROM query.o_issuemulticateventpermitauth  cepa
                               JOIN api.relationships re
                                   ON re.fromobjectid = cepa.objectid
                         WHERE re.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_IssueMultiCatEventPermitAuth',
                                   'AdditionalCondition')
                           AND cepa.objectid = a_objectid)
                LOOP
                    t_relationshipid   :=
                        api.pkg_relationshipupdate.new(
                            t_procaddconditionalendpointid,
                            c.processid,
                            d.addconditionobjectid);
                    pkg_copy.copystoredobjectdetails(d.addconditionobjectid,
                                                     t_relationshipid);
                END LOOP;
            END IF;
        END LOOP;
    END;
END pkg_issuelicense;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_ISSUELICENSE TO POSSEEXTENSIONS;
