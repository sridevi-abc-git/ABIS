CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_COPY_LICENSE"
IS
    -- **************************************************************************
    -- File:        PKG_COPY_LICENSE.PKB
    -- Author:      CX
    --
    -- $Rev: 421 $
    -- $Date: 2020-03-13 18:59:35 -0700 (Fri, 13 Mar 2020) $
    -- Last Changed By:  $Author: PKaur $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                       Comment
    -- 08/16/2018 TJL             Initial Check-in
    -- 02/18/2020 PK     WO-20669 Adding Email functionality for price posting and changeing this
    --                            procedure to Copy Email details and relationsihps from license to
    --                            an application to transfer or change a license.
    -- 06/9/2023  NZA             Updated CopyPriorityLicDetailsToApp due to max object id issue.
    -- 05/08/2025 PK              Added code to copy food Lesse to license job 
    -- **************************************************************************

    -- Public constant declarations
    t_addrmailobjid                 udt_id;
    t_applegalentityappepid         udt_id;
    t_applegalentityosmepid         udt_id;
    t_applegalentityflappepid       udt_id;
    t_applegalentityp12epid         udt_id;
    t_applegalentityprip12id        udt_id;
    t_applicationtype               query.j_application.applicationtype%TYPE;
    t_copyprocalreadyran            query.j_application.copylicdetailstoappprochasrun%TYPE;
    t_createrelendpointid           udt_id;
    t_dbanewobjid                   udt_id;
    t_droppartner                   query.j_application.droppartner%TYPE;
    t_endpointid                    udt_id;
    t_fiduciarytransfer             query.j_application.fiduciarytransfer%TYPE;
    t_fiduciarytype                 query.j_application.fiduciarytype%TYPE;
    t_legalentityobjid              udt_id;
    t_licensetypeexchange           query.j_application.licensetypeexchange%TYPE;
    t_liclelicenseeepid             udt_id;
    t_licleosmepid                  udt_id;
    t_liclefllicepid                udt_id;
    t_liclep12epid                  udt_id;
    t_licleprip12epid               udt_id;
    t_licobjid                      udt_id;
    t_membershiptransfer            query.j_application.membershiptransfer%TYPE;
    t_newobjectid                   udt_id;
    t_newrelobjectid                udt_id;
    t_objectdefid                   udt_id;
    t_persontoperson                query.j_application.persontoperson%TYPE;
    t_premmailingaddrid             udt_id;
    t_prilictypeobjid               udt_id;
    t_premisetopremise              query.j_application.premisetopremise%TYPE;
    t_stocktransfer                 query.j_application.stocktransfer%TYPE;
    t_ispriorityapplication         query.j_application.ispriorityapplication%TYPE;
    t_governmentowned               query.j_application.conda%TYPE;
    t_mailingaddress                query.j_application.mailingaddress%TYPE;
    t_lepersonepid                  udt_id;
    t_lecompanyepid                 udt_id;
    t_duplicateapplicant            udt_id;
    t_duplicatelicensetype          udt_id;
    t_prioritycopyprocedurehasrun   query.j_application.prioritycopyprocedurehasrun%TYPE;
    t_prilictypecount               NUMBER;
    t_licensetypecount              NUMBER;
    t_licemailobjid                 udt_id; -- added by Pawan WO-20669

    ---------------------------------------------------------------------------------------------------
    --   * CopyLicDetailsToApp() -- PUBLIC
    -- Copy details and relationsihps from license to an application to transfer or change a license.
    -- Inputs are the license id, to find the existing details, and the application id, to know where
    -- to copy the details and relationsihps.
    ---------------------------------------------------------------------------------------------------
    -- Public function and procedure declarations

    PROCEDURE copylicdetailstoapp(a_appobjectid udt_id, a_asofdate DATE)
    IS
        t_licenseexternalfilenum      VARCHAR(40);
        t_appexternalfilenum          VARCHAR(40);
        t_addprimarylicensetypeonly   VARCHAR(1);
        t_p12legalenityobjectid       api.pkg_definition.udt_id;
        t_transfertonew               VARCHAR(1);
        t_transferfromobjid           udt_id;
        t_transfertoobjid             udt_id;
        t_donotcopyexternal           VARCHAR(1) := 'Y';
    BEGIN

        t_applegalentityappepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Applicant');
        t_applegalentityosmepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'OnSaleManager');
        t_applegalentityflappepid :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'FoodLesseeApp');  -- 05/08/2025 PK              Added code to copy food Lesse to license job 
        t_applegalentityp12epid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'P12Applicant');
        t_applegalentityprip12id   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'PrimaryP12Applicant');

        t_liclelicenseeepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'LicenseeLegalEntity');
        t_licleosmepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'OSMLegalEntity');
        t_liclefllicepid :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'FoodLesseeLic');  -- 05/08/2025 PK              Added code to copy food Lesse to license job 
        t_liclep12epid   :=
            api.pkg_configquery.endpointidforname('j_License', 'P12Licensee');
        t_licleprip12epid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'PrimaryP12Licensee');

        BEGIN
            SELECT applicationtype, -- app details to determine what all needs to be copied from license
                   droppartner,
                   fiduciarytransfer,
                   fiduciarytype,
                   licensetypeexchange,
                   membershiptransfer,
                   persontoperson,
                   premisetopremise,
                   stocktransfer,
                   CASE
                       WHEN addprimarylicensetype = 'Y'
                        AND licensetypeexchange = 'N'
                        AND stocktransfer = 'N'
                        AND membershiptransfer = 'N' THEN
                           'Y'
                       ELSE
                           'N'
                   END,
                   copylicdetailstoappprochasrun,
                   ispriorityapplication,
                   conda,
                   newlicensetransferringto
              INTO t_applicationtype,
                   t_droppartner,
                   t_fiduciarytransfer,
                   t_fiduciarytype,
                   t_licensetypeexchange,
                   t_membershiptransfer,
                   t_persontoperson,
                   t_premisetopremise,
                   t_stocktransfer,
                   t_addprimarylicensetypeonly,
                   t_copyprocalreadyran,
                   t_ispriorityapplication,
                   t_governmentowned,
                   t_transfertonew
              FROM query.j_application
             WHERE objectid = a_appobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'ERROR obtaining details of Application');
        END;

        IF t_applicationtype IN ('Change', 'Transfer')
       AND t_copyprocalreadyran = 'N' THEN
            -- run this procedure and set the flag to Y at the end.

            -- Find the existing license affected by this application.
            IF t_applicationtype = 'Change' THEN
                BEGIN
                    SELECT toobjectid
                      INTO t_licobjid
                      FROM api.relationships
                     WHERE fromobjectid = a_appobjectid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'License');
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                            'ERROR determining License being changed. ');
                END;
            ELSIF t_applicationtype = 'Transfer'
              AND t_transfertonew = 'Y'
               OR (t_persontoperson = 'N'
               AND t_premisetopremise = 'N'
               AND t_licensetypeexchange = 'N') THEN
                BEGIN
                    SELECT toobjectid
                      INTO t_licobjid
                      FROM api.relationships
                     WHERE fromobjectid = a_appobjectid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'LicenseTransfer');
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(
                            -20001,
                            'ERROR determining License being transferred. ');
                END;
            ELSIF t_applicationtype = 'Transfer'
              AND t_transfertonew = 'N' THEN
                BEGIN
                    SELECT toobjectid
                      INTO t_licobjid
                      FROM api.relationships
                     WHERE fromobjectid = a_appobjectid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'LicenseTransferTo');

                    SELECT toobjectid
                      INTO t_transferfromobjid
                      FROM api.relationships
                     WHERE fromobjectid = a_appobjectid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'LicenseTransfer');

                    t_donotcopyexternal   := 'N';
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(
                            -20001,
                            'ERROR determining License being transferred to.');
                END;
            ELSE
                api.pkg_errors.raiseerror(
                    -20001,
                    'ERROR determining License being transferred or changed.');
            END IF;

            --Get the License Number from the License and set the Application External File Number to the License Number
            IF t_applicationtype = 'Change'
            OR t_applicationtype = 'Transfer'
           AND (t_donotcopyexternal = 'N') THEN
                t_licenseexternalfilenum   :=
                    api.pkg_columnquery.VALUE(t_licobjid, 'ExternalFileNum');

                t_appexternalfilenum   :=
                       t_licenseexternalfilenum
                    || '-'
                    || LPAD(TRUNC(TO_CHAR(SYSDATE, 'YYMMDD')), 6, '0');

                SELECT    t_appexternalfilenum
                       || CASE
                              WHEN COUNT(*) > 0 THEN ' ' || COUNT(*)
                              ELSE NULL
                          END
                  INTO t_appexternalfilenum
                  FROM api.jobs a
                 WHERE a.jobtypeid =
                       api.pkg_configquery.objectdefidforname(
                           'j_Application')
                   AND a.externalfilenum LIKE t_appexternalfilenum || '%';

                api.pkg_jobupdate.setexternalfilenum(a_appobjectid,
                                                     t_appexternalfilenum);
            END IF;

            /*begin --Copy the Government Owned detail to the Application
             select l.governmentowned
               into t_GovernmentOwned
               from query.j_license l
              where l.objectid = t_LicObjId;
             api.pkg_columnupdate.SetValue(a_AppObjectId, 'CONDA', t_GovernmentOwned);
            end;*/

            BEGIN
                --Copy the Felony and Violation details from the License.

                api.pkg_columnupdate.setvalue(
                    a_appobjectid,
                    'Felony',
                    api.pkg_columnquery.VALUE(t_licobjid, 'Felony'));
                api.pkg_columnupdate.setvalue(
                    a_appobjectid,
                    'Violation',
                    api.pkg_columnquery.VALUE(t_licobjid, 'Violation'));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20001,
                           'ERROR copying Felony and Violation details. '
                        || SQLERRM);
            END;

            IF t_applicationtype = 'Transfer' THEN --QWE Do the holds from the To and From need to Copy?
                BEGIN
                    -- Look for Unreleased Hold on Transfer License; relate to Appliction
                    -- 04.07 TODO A new instance of hold object, or relate app to exsiting hold object?
                    FOR c_hold
                        IN (SELECT r.toobjectid holdobjid
                              FROM api.relationships  r
                                   JOIN query.o_hold h
                                       ON h.objectid = r.toobjectid
                             WHERE r.fromobjectid = t_licobjid
                               AND h.holdreleased IS NULL
                               AND endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_License',
                                       'Hold'))
                    LOOP
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_Application',
                                    'Hold'),
                                a_appobjectid,
                                c_hold.holdobjid);
                    END LOOP;                     -- Holds on transfer license
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;            -- Hold is optional, so just move on.
                END;                    -- Unreleased Hold on Transfer License
            END IF;                                          -- Transfer tasks

            -- Do not carry forward conditions for a premise to premise transfer
            -- NW March 2017 Conditions Project
            IF t_premisetopremise = 'N' THEN
                -- Get EndPointIds and ObjectDefIds for Condition copying
                t_endpointid   :=
                    api.pkg_configquery.endpointidforname('j_Application',
                                                          'Condition');
                t_objectdefid   :=
                    api.pkg_configquery.objectdefidforname(
                        'o_AdditionalCondition');

                -- Copy Conditions to Application
                FOR c IN (SELECT *
                            FROM query.r_licensecondition r
                           WHERE r.licensejobid = t_licobjid)
                LOOP
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_endpointid,
                                                       a_appobjectid,
                                                       c.conditionobjectid);
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'IsProcedureCreated',
                                                  'Y');
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'ConditionText',
                                                  c.conditiontext);
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'ConditionCode',
                                                  c.conditioncode);
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'ConditionRelCount',
                                                  c.conditionrelcount);
                    api.pkg_columnupdate.setvalue(t_newrelobjectid,
                                                  'Sort',
                                                  c.sort);
                END LOOP;

                -- Copy Additional Conditions to Application
                t_endpointid   :=
                    api.pkg_configquery.endpointidforname('j_Application',
                                                          'AdditCondition');

                FOR x
                    IN (SELECT ac.objectid, ac.sort2, ac.conditiontext
                          FROM query.r_licenseadditioncondition  r
                               JOIN query.o_additionalcondition ac
                                   ON ac.objectid =
                                      r.additionalconditionobjectid
                         WHERE r.licensejobid = t_licobjid)
                LOOP
                    t_newobjectid   :=
                        api.pkg_objectupdate.new(t_objectdefid);
                    api.pkg_columnupdate.setvalue(t_newobjectid,
                                                  'ConditionText',
                                                  x.conditiontext);
                    api.pkg_columnupdate.setvalue(t_newobjectid,
                                                  'Sort2',
                                                  x.sort2);
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_endpointid,
                                                       a_appobjectid,
                                                       t_newobjectid);
                END LOOP;
            END IF;


            BEGIN
                -- find Mailing Address on Transfer and Change license, if exists, and relate to application
                IF t_applicationtype IN ('Transfer', 'Change') --QWE Copy address from transfer to
               AND t_persontoperson <> 'Y' THEN
                    SELECT toobjectid
                      INTO t_addrmailobjid
                      FROM api.relationships
                     WHERE fromobjectid = t_licobjid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_License',
                               'MailingAddress');

                    -- relate the Application to the mailing address
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'MailingAddress'),
                            a_appobjectid,
                            t_addrmailobjid);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;                                            -- Mailing Address

            BEGIN
                -- find Premises Address on Upgrade license, if exists, and relate to application
                IF (api.pkg_columnquery.VALUE(a_appobjectid,
                                              'PriorityUpgrade')) =
                   'Yes'
                OR t_premisetopremise = 'N' THEN
                    SELECT toobjectid
                      INTO t_premmailingaddrid
                      FROM api.relationships
                     WHERE fromobjectid = t_licobjid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname('j_License',
                                                                 'Premises');

                    -- relate the Application to the mailing address
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'Premises'),
                            a_appobjectid,
                            t_premmailingaddrid);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;                                           -- Premises Address

            BEGIN -- WO-20669 Added by Pawan for Priceposting email on 2/18/2020
                -- find Email Address on Transfer and Change license, if exists, and relate to application
                IF t_applicationtype IN ('Transfer', 'Change') --QWE Copy address from transfer to
               AND t_persontoperson <> 'Y' THEN
                    SELECT toobjectid
                      INTO t_licemailobjid
                      FROM api.relationships
                     WHERE fromobjectid = t_licobjid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_License',
                               'LicenseEmail');

                    -- relate the Application to the Email address
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'ApplicationEmail'),
                            a_appobjectid,
                            t_licemailobjid);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;  -- WO-20669 Added by Pawan for Priceposting email on 2/18/2020  -- Email Address

            IF t_persontoperson <> 'Y' THEN
                FOR c_dba IN (SELECT                 -- Active DBAs on License
                                     r.toobjectid licdbaobjid
                                FROM api.relationships  r
                                     JOIN query.o_dbanames d
                                         ON (d.objectid = r.toobjectid
                                         AND endpointid =
                                             api.pkg_configquery.endpointidforname(
                                                 'j_License',
                                                 'DBANames')
                                         AND d.active = 'Y')
                               WHERE r.fromobjectid = t_licobjid)
                LOOP
                    t_dbanewobjid   :=
                        api.pkg_objectupdate.new(
                            api.pkg_configquery.objectdefidforname(
                                'o_DBANames'));

                    -- Copy stored dynamic details from existing DBA
                    pkg_copy.copystoredobjectdetails(c_dba.licdbaobjid,
                                                     t_dbanewobjid);

                    -- relate this DBA object to the Application
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'DBANames'),
                            a_appobjectid,
                            t_dbanewobjid);
                END LOOP;                            -- Active DBAs on License
            END IF;

            BEGIN
                --   START Licensees copied as Applicants.
                IF (t_applicationtype = 'Change'
                 OR (t_applicationtype = 'Transfer'
                 AND t_persontoperson <> 'Y'))
               AND ((t_fiduciarytype IS NOT NULL
                 AND t_fiduciarytype NOT LIKE '%SELF INCORPORATION%')
                 OR t_fiduciarytype IS NULL) THEN
                    -- Find the Legal Entites on the License
                    FOR c_le IN (SELECT toobjectid, endpointid
                                   FROM api.relationships
                                  WHERE fromobjectid = t_licobjid
                                    AND endpointid IN (t_liclelicenseeepid,
                                                       t_licleosmepid,
                                                       t_liclefllicepid,
                                                       t_liclep12epid,
                                                       t_licleprip12epid))
                    LOOP
                        IF c_le.endpointid NOT IN
                               (t_liclep12epid, t_licleprip12epid) THEN
                            -- Copy the Legal Entity associated with the License
                            t_legalentityobjid   :=
                                pkg_legalentity.legalentitycopy(
                                    c_le.toobjectid);
                        ELSE
                            -- the existing P12 legal entity will be related to the application.
                            t_legalentityobjid   := c_le.toobjectid;
                        END IF;

                        -- Get the endpoint for the rel from license to LE
                        CASE
                            WHEN c_le.endpointid = t_liclelicenseeepid THEN
                                t_createrelendpointid   :=
                                    t_applegalentityappepid;
                            WHEN c_le.endpointid = t_licleosmepid THEN
                                t_createrelendpointid   :=
                                    t_applegalentityosmepid;
                            WHEN c_le.endpointid = t_liclefllicepid THEN
                                t_createrelendpointid   :=
                                    t_applegalentityflappepid;
                            WHEN c_le.endpointid = t_liclep12epid THEN
                                t_createrelendpointid   :=
                                    t_applegalentityp12epid;
                            WHEN c_le.endpointid = t_licleprip12epid THEN --When Looking at the Primary P12 Legal Entity Relationship copy it the the application
                                t_createrelendpointid   :=
                                    t_applegalentityprip12id;
                        END CASE;

                        -- Relate the Legal Entity as Applicant on the Application
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                t_createrelendpointid,
                                a_appobjectid,
                                t_legalentityobjid);
                    END LOOP;                 -- Legal Entities on Application

                    SELECT p12legalenityobjectid
                      INTO t_p12legalenityobjectid
                      FROM query.j_application a
                     WHERE a.objectid = a_appobjectid;

                    api.pkg_columnupdate.setvalue(
                        a_appobjectid,
                        'P12LegalEnityObjectIdStored',
                        t_p12legalenityobjectid);
                END IF; -- Determine Application Types requiring Licensees copied as Applicants
            EXCEPTION
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20001,
                           'Legal Entity ERROR. '
                        || ' RelEndPointID: '
                        || t_createrelendpointid
                        || ' a_AppObjectId: '
                        || a_appobjectid
                        || ' t_LegalEntityObjId: '
                        || t_legalentityobjid
                        || SQLERRM);
            END;                     --   END  Licensees copied as Applicants.

            BEGIN
                --   START License Types copied to Application

                --If this is a transfer to an active license copy the license types from the transfered from license
                --Do this by setting the t_LicObjId to the TransferfromObjId after license types are copied set t_LicObjId back to t_TransferToObjId
                IF t_applicationtype = 'Transfer'
               AND t_transfertonew = 'N'
               AND (t_persontoperson = 'Y'
                 OR t_premisetopremise = 'Y'
                 OR t_licensetypeexchange = 'Y') THEN
                    t_transfertoobjid   := t_licobjid;
                    t_licobjid          := t_transferfromobjid;
                END IF;

                SELECT COUNT(*)
                  INTO t_prilictypecount
                  FROM query.j_licensetype  lt
                       JOIN query.o_licensetypecategory ltc
                           ON ltc.licensetypecode = lt.licensetypecode
                       JOIN api.relationships r
                           ON (r.toobjectid = lt.objectid
                           AND r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_License',
                                   'LicenseType'))
                 WHERE r.fromobjectid = t_licobjid
                   AND lt.statusname IN ('ACTIVE',
                                         'SUREND',
                                         'PEND',
                                         'R64B',
                                         'SUSPEN',
                                         'SLMSHD',
                                         'REVPEN'); --Change this line to include the statuses KL added, all after PEND

                SELECT COUNT(*)
                  INTO t_licensetypecount
                  FROM query.j_licensetype  lt
                       JOIN query.o_licensetypecategory ltc
                           ON ltc.licensetypecode = lt.licensetypecode
                       JOIN api.relationships r
                           ON (r.toobjectid = lt.objectid
                           AND r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_License',
                                   'LicenseType'))
                 WHERE r.fromobjectid = t_licobjid;

                IF t_prilictypecount = 0
               AND t_licensetypecount > 0 THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'The License Transferring From does not contain any applicable Primary License Types for a transfer.');
                END IF;

                -- Don't copy any Licenses over if this is a change to Add a PLT
                IF t_addprimarylicensetypeonly = 'N' THEN
                    FOR c_2
                        IN (SELECT lt.objectid                 prilictypeobjid,
                                   ltc.objectid                ltcatobjid,
                                   lt.licensetypecode,
                                   UPPER(lt.statusdescription) status,
                                   lt.jobid                    ltjobid
                              FROM query.j_licensetype  lt
                                   JOIN query.o_licensetypecategory ltc
                                       ON ltc.licensetypecode =
                                          lt.licensetypecode
                                   JOIN api.relationships r
                                       ON (r.toobjectid = lt.objectid
                                       AND r.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'j_License',
                                               'LicenseType'))
                             WHERE r.fromobjectid = t_licobjid
                               AND lt.statusname IN ('ACTIVE',
                                                     'SUREND',
                                                     'PEND',
                                                     'R64B',
                                                     'SUSPEN',
                                                     'SLMSHD',
                                                     'REVPEN'))
                    LOOP
                        BEGIN
                            -- Create and relate Primary License Type to Application, and License Type Category
                            -- Create new Primary License Type Object
                            t_prilictypeobjid   :=
                                api.pkg_objectupdate.new(
                                    api.pkg_configquery.objectdefidforname(
                                        'o_PrimaryLicenseType'));

                            -- If the application is a Transfer, create the Transfer rel from the License Type to the PLT object
                            IF t_applicationtype = 'Transfer' THEN --QWE do I need this rel if so from the trans to or trans from?
                                t_newrelobjectid   :=
                                    api.pkg_relationshipupdate.new(
                                        api.pkg_configquery.endpointidforname(
                                            'j_LicenseType',
                                            'TransToPrimaryLicenseType'),
                                        c_2.prilictypeobjid,
                                        t_prilictypeobjid);
                            -- If the application is a Change, create the Change rel from the License Type to the PLT Object.
                            ELSIF t_applicationtype = 'Change' THEN
                                t_newrelobjectid   :=
                                    api.pkg_relationshipupdate.new(
                                        api.pkg_configquery.endpointidforname(
                                            'j_LicenseType',
                                            'ChangePrimaryLicenseType'),
                                        c_2.prilictypeobjid,
                                        t_prilictypeobjid);
                            END IF;

                            -- Set the Is Transferred detail
                            api.pkg_columnupdate.setvalue(
                                t_prilictypeobjid,
                                api.pkg_configquery.columndefidforname(
                                    'o_PrimaryLicenseType',
                                    'IsAutoTransfer'),
                                'Y');

                            -- Set the Status Detail  ---QWE should I set this?
                            IF t_applicationtype = 'Change' THEN
                                api.pkg_columnupdate.setvalue(
                                    t_prilictypeobjid,
                                    'Status',
                                    c_2.status);
                            END IF;

                            -- Copy stored details from License Type object from Lic to Primary License Type Job of App --QWE what happens for bonded winery numbers
                            -- if the Application is a Transfer and the person or coperation is changing do not copy the Bonded Winery #
                            IF t_applicationtype = 'Transfer'
                           AND (t_premisetopremise = 'Y'
                            AND (t_persontoperson = 'Y'
                              OR t_fiduciarytransfer = 'Y'
                              OR t_licensetypeexchange = 'Y'
                              OR t_droppartner = 'Y')) THEN
                                pkg_copy.copystoredobjdetailsexception(
                                    c_2.prilictypeobjid,
                                    t_prilictypeobjid,
                                    'BondedWinery');
                            ELSE
                                pkg_copy.copystoredobjectdetails(
                                    c_2.prilictypeobjid,
                                    t_prilictypeobjid);
                            END IF;

                            -- relate the new Primary License Type job to the Application
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_Application',
                                        'PrimaryLicenseType'),
                                    a_appobjectid,
                                    t_prilictypeobjid);

                            -- relate the new Primary License Type Job to the License Type Category object.
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'o_PrimaryLicenseType',
                                        'LicTypeCatPrimary'),
                                    t_prilictypeobjid,
                                    c_2.ltcatobjid);

                            -- Look for existing Secondary license types associated with the existing License Type. Copy.
                            FOR c_sec
                                IN (SELECT r.toobjectid     secltobjid -- 04.21 adding logic copy Secondary LT count
                                                                      ,
                                           r.relationshipid licrelltsecltc
                                      FROM api.relationships r
                                     WHERE r.fromobjectid =
                                           c_2.prilictypeobjid
                                       AND r.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'j_LicenseType',
                                               'LicTypeCatSecondary')
                                       AND api.pkg_columnquery.VALUE(
                                               r.relationshipid,
                                               'Status') IN
                                               ('ACTIVE',
                                                'SURRENDERED',
                                                'PENDING',
                                                'RULE 64B',
                                                'SUSPENDED',
                                                'SLMS HOLD',
                                                'REV PENDING'))
                            LOOP
                                -- SecondaryLicenseTypeCategory
                                -- Relate the new Primary License Type Job to the Secondary License Type Category object.
                                t_newrelobjectid   :=
                                    api.pkg_relationshipupdate.new(
                                        api.pkg_configquery.endpointidforname(
                                            'o_PrimaryLicenseType',
                                            'LicTypeCatSecondary'),
                                        t_prilictypeobjid,
                                        c_sec.secltobjid);

                                -- Copy License Type count
                                pkg_copy.copystoredobjectdetails(
                                    c_sec.licrelltsecltc,
                                    t_newrelobjectid);

                                IF t_applicationtype = 'Change' THEN
                                    api.pkg_columnupdate.setvalue(
                                        t_newrelobjectid,
                                        'SStatus',
                                        api.pkg_columnquery.VALUE(
                                            c_sec.licrelltsecltc,
                                            'Status'));
                                END IF;

                                -- Set the Is Transferred detail
                                api.pkg_columnupdate.setvalue(
                                    t_newrelobjectid,
                                    'IsAutoTransfer',
                                    'Y');

                                FOR c_dup
                                    IN (SELECT d.duplicateid objectid
                                          FROM sitespecific.duplicate_t d
                                         WHERE d.licensetypejobid =
                                               c_2.ltjobid
                                           AND d.licensetypecategoryobjectid =
                                               c_sec.secltobjid)
                                LOOP
                                    --Copy duplicate objects to application
                                    t_newobjectid   :=
                                        api.pkg_objectupdate.new(
                                            api.pkg_configquery.objectdefidforname(
                                                'o_Duplicate'));

                                    --  Copy the Duplicate Details
                                    --note that it is important to set the license type category object id before anything else otherwise it errors.
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'LicenseTypeCategoryObjectID',
                                        api.pkg_columnquery.VALUE(
                                            c_dup.objectid,
                                            'LicenseTypeCategoryObjectID'));
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'Description',
                                        api.pkg_columnquery.VALUE(
                                            c_dup.objectid,
                                            'Description'));
                                    pkg_copy.copystoredobjdetailsexception(
                                        c_dup.objectid,
                                        t_newobjectid,
                                        'IssueDate,LicenseTypeJobId');

                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'PrimaryLicenseTypeObjectID',
                                        t_prilictypeobjid);
                                END LOOP;
                            END LOOP; -- Secondary LT to License Type Category

                            --If this is a Transfer App copy the Master/Branch relationships over onto the new o_PrimaryLicenseTypes
                            IF t_applicationtype <> 'Original' THEN
                                --get the Branch License Type Id(s)
                                FOR c_m
                                    IN (SELECT ma.toobjectid branchid,
                                               lt.masterlicensetype
                                          FROM query.j_licensetype  lt
                                               JOIN api.relationships ma
                                                   ON ma.fromobjectid =
                                                      lt.objectid
                                                  AND ma.endpointid =
                                                      api.pkg_configquery.endpointidforname(
                                                          'j_LicenseType',
                                                          'BranchLicenseType')
                                         WHERE lt.jobid = c_2.prilictypeobjid)
                                LOOP
                                    --When the LicenseType is a Master create the rel from the new Master o_PrimaryLicenseType to the 'old' Branch j_LicenseType

                                    t_newrelobjectid   :=
                                        api.pkg_relationshipupdate.new(
                                            api.pkg_configquery.endpointidforname(
                                                'o_PrimaryLicenseType',
                                                'MasterPrimaryLicenseType'),
                                            t_prilictypeobjid,
                                            c_m.branchid);
                                END LOOP;

                                --copy the branch relationship over
                                --get the Master License Type id
                                FOR c_b
                                    IN (SELECT br.toobjectid masterid,
                                               lt.masterlicensetype
                                          FROM query.j_licensetype  lt
                                               JOIN api.relationships br
                                                   ON br.fromobjectid =
                                                      lt.objectid
                                                  AND br.endpointid =
                                                      api.pkg_configquery.endpointidforname(
                                                          'j_LicenseType',
                                                          'MasterLicenseType')
                                         WHERE lt.jobid = c_2.prilictypeobjid)
                                LOOP
                                    --set the relationship between the Master j_LicenseType and the new Branch o_PrimaryLicenseType
                                    t_newrelobjectid   :=
                                        api.pkg_relationshipupdate.new(
                                            api.pkg_configquery.endpointidforname(
                                                'j_LicenseType',
                                                'BranchPrimaryLicenseType'),
                                            c_b.masterid,
                                            t_prilictypeobjid);
                                END LOOP;

                                --Get the Branch Primary License Type Ids
                                FOR c_m2
                                    IN (SELECT ma.toobjectid branchid,
                                               lt.masterlicensetype
                                          FROM query.j_licensetype  lt
                                               JOIN api.relationships ma
                                                   ON ma.fromobjectid =
                                                      lt.objectid
                                                  AND ma.endpointid =
                                                      api.pkg_configquery.endpointidforname(
                                                          'j_LicenseType',
                                                          'BranchPrimaryLicenseType')
                                         WHERE lt.jobid = c_2.prilictypeobjid
                                           AND (SELECT api.pkg_columnquery.VALUE(
                                                           r.applicationobjectid,
                                                           'StatusDescription')
                                                  FROM query.r_appprimarylicensetype
                                                       r
                                                 WHERE r.licensetypeobjectid =
                                                       ma.toobjectid) NOT IN
                                                   ('Voided',
                                                    'Withdrawn',
                                                    'Issued')
                                           AND (SELECT api.pkg_columnquery.VALUE(
                                                           r.applicationobjectid,
                                                           'ApplicationType')
                                                  FROM query.r_appprimarylicensetype
                                                       r
                                                 WHERE r.licensetypeobjectid =
                                                       ma.toobjectid) NOT IN
                                                   ('Change'))
                                LOOP
                                    --When the LicenseType is a Master create the rel from the new Master o_PrimaryLicenseType to the 'old' Branch j_LicenseType

                                    t_newrelobjectid   :=
                                        api.pkg_relationshipupdate.new(
                                            api.pkg_configquery.endpointidforname(
                                                'o_PrimaryLicenseType',
                                                'MastertoBranch'),
                                            t_prilictypeobjid,
                                            c_m2.branchid);
                                END LOOP;

                                --Get the Master Primary License Type Ids
                                FOR c_m2
                                    IN (SELECT ma.toobjectid branchid,
                                               lt.masterlicensetype
                                          FROM query.j_licensetype  lt
                                               JOIN api.relationships ma
                                                   ON ma.fromobjectid =
                                                      lt.objectid
                                                  AND ma.endpointid =
                                                      api.pkg_configquery.endpointidforname(
                                                          'j_LicenseType',
                                                          'MasterBranchLicenseType')
                                         WHERE lt.jobid = c_2.prilictypeobjid
                                           AND (SELECT api.pkg_columnquery.VALUE(
                                                           r.applicationobjectid,
                                                           'StatusDescription')
                                                  FROM query.r_appprimarylicensetype
                                                       r
                                                 WHERE r.licensetypeobjectid =
                                                       ma.toobjectid) NOT IN
                                                   ('Voided',
                                                    'Withdrawn',
                                                    'Issued')
                                           AND (SELECT api.pkg_columnquery.VALUE(
                                                           r.applicationobjectid,
                                                           'ApplicationType')
                                                  FROM query.r_appprimarylicensetype
                                                       r
                                                 WHERE r.licensetypeobjectid =
                                                       ma.toobjectid) NOT IN
                                                   ('Change'))
                                LOOP
                                    --When the LicenseType is a Branch create the rel from the new Branch o_PrimaryLicenseType to the Master o_PLT
                                    t_newrelobjectid   :=
                                        api.pkg_relationshipupdate.new(
                                            api.pkg_configquery.endpointidforname(
                                                'o_PrimaryLicenseType',
                                                'BranchtoMaster'),
                                            t_prilictypeobjid,
                                            c_m2.branchid);
                                END LOOP;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS THEN
                                api.pkg_errors.raiseerror(
                                    -20000,
                                       ' . ERROR copying License Type to Application. '
                                    || SQLERRM);
                        END; -- Create and relate License Types to Application, and License Type Category
                    END LOOP;            -- License Types on existing License.
                END IF;

                --Now that the License Types have been copied set the copy from License back to the TransferTo
                IF t_applicationtype = 'Transfer'
               AND t_transfertonew = 'N'
               AND (t_persontoperson = 'Y'
                 OR t_premisetopremise = 'Y'
                 OR t_licensetypeexchange = 'Y') THEN
                    t_transferfromobjid   := t_licobjid;
                    t_licobjid            := t_transfertoobjid;
                END IF;

                IF t_applicationtype = 'Change'
                OR (t_applicationtype = 'Transfer'
                AND t_premisetopremise <> 'Y') THEN
                    api.pkg_columnupdate.setvalue(
                        a_appobjectid,
                        'OverriddenGeocodedX',
                        api.pkg_columnquery.VALUE(t_licobjid,
                                                  'OverriddenGeocodedX'));
                    api.pkg_columnupdate.setvalue(
                        a_appobjectid,
                        'OverriddenGeocodedY',
                        api.pkg_columnquery.VALUE(t_licobjid,
                                                  'OverriddenGeocodedY'));
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           ' . ERROR License Status could not be determined.'
                        || SQLERRM);
            /*WHEN OTHERS THEN -- removed 6/24/2009 for interfering with the api.pkg_errors.raiseerror above
            api.pkg_Errors.RaiseError(-20000, ' . ERROR determining License Types on existing License' || SQLERRM);*/

            END; --   END License Types copied for Apps involving License Type Exchange

            -- set bool to Y to indicate this procedure has been run for this application.
            api.pkg_columnupdate.setvalue(a_appobjectid,
                                          'CopyLicDetailsToAppProcHasRun',
                                          'Y');
        END IF;                                     -- IF t_CopyProcAlreadyRan

    END;                                  -- procedure CopyLicDetailsToApp end

    ----------------------------------------------------------------------------------------------------
    -- * CopyPriorityLicDetailsToApp() -- PUBLIC
    -- This is used on the Priority Application.
    -- Copy details and relationsihps from license to an transfer application.
    -- Inputs are the license id, to find the existing details, and the application id, to know where
    -- to copy the details and relationsihps.
    ---------------------------------------------------------------------------------------------------
    -- Public function and procedure declarations

    PROCEDURE copyprioritylicdetailstoapp(a_appobjectid   udt_id,
                                          a_asofdate      DATE)
    IS
    BEGIN

        t_applegalentityappepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Applicant');
        t_applegalentityosmepid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'OnSaleManager');
        t_applegalentityflappepid :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'FoodLesseeApp');  -- 05/08/2025 PK              Added code to copy food Lesse to license job 
        t_applegalentityp12epid   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'P12Applicant');
        t_applegalentityprip12id   :=
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'PrimaryP12Applicant');

        t_liclelicenseeepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'LicenseeLegalEntity');
        t_licleosmepid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'OSMLegalEntity');
        t_liclefllicepid :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'FoodLesseeLic');  -- 05/08/2025 PK              Added code to copy food Lesse to license job 
        t_liclep12epid   :=
            api.pkg_configquery.endpointidforname('j_License', 'P12Licensee');
        t_licleprip12epid   :=
            api.pkg_configquery.endpointidforname('j_License',
                                                  'PrimaryP12Licensee');

        t_lepersonepid   :=
            api.pkg_configquery.endpointidforname('o_LegalEntity', 'Person');
        t_lecompanyepid   :=
            api.pkg_configquery.endpointidforname('o_LegalEntity', 'Company');

        BEGIN
            SELECT -- app details to determine what all needs to be copied from license
                   a.applicationtype,
                   a.droppartner,
                   a.fiduciarytransfer,
                   a.fiduciarytype,
                   a.licensetypeexchange,
                   a.membershiptransfer,
                   a.persontoperson,
                   a.premisetopremise,
                   a.stocktransfer,
                   a.ispriorityapplication,
                   a.conda,
                   a.mailingaddress,
                   a.prioritycopyprocedurehasrun
              INTO t_applicationtype,
                   t_droppartner,
                   t_fiduciarytransfer,
                   t_fiduciarytype,
                   t_licensetypeexchange,
                   t_membershiptransfer,
                   t_persontoperson,
                   t_premisetopremise,
                   t_stocktransfer,
                   t_ispriorityapplication,
                   t_governmentowned,
                   t_mailingaddress,
                   t_prioritycopyprocedurehasrun
              FROM query.j_application a
             WHERE objectid = a_appobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'ERROR obtaining details of Application' || SQLERRM);
        END;

        IF t_applicationtype = 'Transfer'
       AND t_prioritycopyprocedurehasrun != 'Y' THEN     -- run this procedure
            -- Find the existing license affected by this application.
            IF t_applicationtype = 'Transfer' THEN
                BEGIN
                    SELECT toobjectid
                      INTO t_licobjid
                      FROM api.relationships
                     WHERE fromobjectid = a_appobjectid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'LicenseTransfer');
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(
                            -20001,
                               'ERROR determining License being transferred. '
                            || SQLERRM);
                END;
            END IF;

            /*    begin --Copy the Government Owned detail to the Application
                 select l.governmentowned
                   into t_GovernmentOwned
                   from query.j_license l
                  where l.objectid = t_LicObjId;
                 api.pkg_columnupdate.SetValue(a_AppObjectId, 'CONDA', t_GovernmentOwned);
                end;*/

            IF t_applicationtype = 'Transfer' THEN
                BEGIN -- Look for Unreleased Hold on Transfer License; relate to Appliction
                    -- 04.07 TODO A new instance of hold object, or relate app to exsiting hold object?
                    FOR c_hold
                        IN (SELECT r.toobjectid holdobjid
                              FROM api.relationships  r
                                   JOIN query.o_hold h
                                       ON h.objectid = r.toobjectid
                             WHERE r.fromobjectid = t_licobjid
                               AND h.holdreleased IS NULL
                               AND endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_License',
                                       'Hold'))
                    LOOP
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_Application',
                                    'Hold'),
                                a_appobjectid,
                                c_hold.holdobjid);
                    END LOOP;                     -- Holds on transfer license
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;            -- Hold is optional, so just move on.
                END;                    -- Unreleased Hold on Transfer License
            END IF;                                          -- Transfer tasks

            BEGIN -- find Mailing Address on Transfer and Change license, if exists, and relate to application
                IF t_applicationtype = 'Transfer'
               AND t_mailingaddress IS NULL THEN
                    SELECT toobjectid
                      INTO t_addrmailobjid
                      FROM api.relationships
                     WHERE fromobjectid = t_licobjid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_License',
                               'MailingAddress');

                    -- relate the Application to the mailing address
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'MailingAddress'),
                            a_appobjectid,
                            t_addrmailobjid);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;                                            -- Mailing Address



            FOR c_dba IN (SELECT                     -- Active DBAs on License
                                 r.toobjectid licdbaobjid
                            FROM api.relationships  r
                                 JOIN query.o_dbanames d
                                     ON (d.objectid = r.toobjectid
                                     AND endpointid =
                                         api.pkg_configquery.endpointidforname(
                                             'j_License',
                                             'DBANames')
                                     AND d.active = 'Y')
                           WHERE r.fromobjectid = t_licobjid)
            LOOP
                t_dbanewobjid   :=
                    api.pkg_objectupdate.new(
                        api.pkg_configquery.objectdefidforname('o_DBANames'));

                -- Copy stored dynamic details from existing DBA
                pkg_copy.copystoredobjectdetails(c_dba.licdbaobjid,
                                                 t_dbanewobjid);

                -- relate this DBA object to the Application
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'DBANames'),
                        a_appobjectid,
                        t_dbanewobjid);
            END LOOP;                                -- Active DBAs on License



            BEGIN                   --   START Licensees copied as Applicants.
                IF (t_applicationtype = 'Transfer'
                AND (t_persontoperson = 'Y'
                  OR t_fiduciarytransfer = 'Y'
                  OR t_droppartner = 'Y')) THEN
                    -- Find the Legal Entites on the License
                    FOR c_le
                        IN (SELECT r.toobjectid,
                                   r.endpointid,
                                   r2.toobjectid r2toobjid
                              FROM api.relationships  r
                                   JOIN api.relationships r2
                                       ON r2.fromobjectid = r.toobjectid
                             WHERE r.fromobjectid = t_licobjid
                               AND r.endpointid IN (t_liclelicenseeepid,
                                                    t_licleosmepid,
                                                    t_liclefllicepid,
                                                    t_liclep12epid,
                                                    t_licleprip12epid)
                               AND r2.endpointid IN
                                       (t_lepersonepid, t_lecompanyepid))
                    LOOP
                        BEGIN

                            SELECT r2.toobjectid toobjectid2
                              INTO t_duplicateapplicant
                              FROM api.relationships  r
                                   JOIN api.relationships r2
                                       ON r2.fromobjectid = r.toobjectid
                             WHERE r.fromobjectid = a_appobjectid
                               AND r.endpointid IN (t_applegalentityappepid,
                                                    t_applegalentityosmepid,
                                                    t_applegalentityflappepid,
                                                    t_applegalentityp12epid,
                                                    t_applegalentityprip12id)
                               AND r2.endpointid IN
                                       (t_lepersonepid, t_lecompanyepid)
                               AND r2.toobjectid = c_le.r2toobjid
                            ORDER BY r.logicaltransactionid DESC
                            fetch first 1 rows only;

                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                t_duplicateapplicant   := NULL;
                        END;

                        IF t_duplicateapplicant IS NULL THEN
                            IF c_le.endpointid <> t_applegalentityp12epid THEN -- Copy the Legal Entity associated with the License
                                t_legalentityobjid   :=
                                    pkg_legalentity.legalentitycopy(
                                        c_le.toobjectid);
                            ELSE -- the existing P12 legal entity will be related to the application.
                                t_legalentityobjid   := c_le.toobjectid;
                            END IF;

                            -- Get the endpoint for the rel from license to LE
                            CASE
                                WHEN c_le.endpointid = t_liclelicenseeepid THEN
                                    t_createrelendpointid   :=
                                        t_applegalentityappepid;
                                WHEN c_le.endpointid = t_licleosmepid THEN
                                    t_createrelendpointid   :=
                                        t_applegalentityosmepid;
                                 WHEN c_le.endpointid = t_liclefllicepid THEN
                                    t_createrelendpointid   :=
                                        t_applegalentityflappepid ;
                                WHEN c_le.endpointid = t_liclep12epid THEN
                                    t_createrelendpointid   :=
                                        t_applegalentityp12epid;
                                WHEN c_le.endpointid = t_licleprip12epid --When Looking at the Primary P12 Legal Entity Relationship copy it the the application
                                                                         THEN
                                    t_createrelendpointid   :=
                                        t_applegalentityprip12id;
                            END CASE;

                            -- Relate the Legal Entity as Applicant on the Application
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    t_createrelendpointid,
                                    a_appobjectid,
                                    t_legalentityobjid);
                        ELSE
                            NULL;
                        END IF;
                    END LOOP;                 -- Legal Entities on Application
                END IF; -- Determine Application Types requiring Licensees copied as Applicants
            EXCEPTION
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20001,
                           'Legal Entity ERROR. '
                        || ' RelEndPointID: '
                        || t_createrelendpointid
                        || ' a_AppObjectId: '
                        || a_appobjectid
                        || ' t_LegalEntityObjId: '
                        || t_legalentityobjid
                        || SQLERRM);
            END;                     --   END  Licensees copied as Applicants.

            BEGIN               --   START License Types copied to Application
                FOR c_2
                    IN (SELECT lt.objectid   lictypejobid,
                               ltc.objectid  ltcatobjid,
                               r2.toobjectid ltcobjectid
                          FROM query.j_licensetype  lt
                               JOIN query.o_licensetypecategory ltc
                                   ON ltc.licensetypecode =
                                      lt.licensetypecode
                               JOIN api.relationships r
                                   ON (r.toobjectid = lt.objectid
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'j_License',
                                           'LicenseType'))
                               JOIN api.relationships r2
                                   ON (r2.fromobjectid = r.toobjectid
                                   AND r2.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'j_LicenseType',
                                           'LicTypeCatPrimary'))
                         WHERE r.fromobjectid = t_licobjid
                           AND lt.statusname IN ('ACTIVE', 'SUREND', 'PEND'))
                LOOP
                    BEGIN
                        SELECT r2.toobjectid
                          INTO t_duplicatelicensetype
                          FROM api.relationships  r
                               JOIN api.relationships r2
                                   ON r2.fromobjectid = r.toobjectid
                         WHERE r.fromobjectid = a_appobjectid
                           AND r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_Application',
                                   'PrimaryLicenseType')
                           AND r2.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_PrimaryLicenseType',
                                   'LicTypeCatPrimary')
                           AND r2.toobjectid = c_2.ltcobjectid;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_duplicatelicensetype   := NULL;
                    END;

                    IF t_duplicatelicensetype IS NULL THEN
                        BEGIN -- Create and relate Primary License Type to Application, and License Type Category
                            -- Create new Primary License Type Object
                            t_prilictypeobjid   :=
                                api.pkg_objectupdate.new(
                                    api.pkg_configquery.objectdefidforname(
                                        'o_PrimaryLicenseType'));
                            -- Set the Is Transferred detail
                            api.pkg_columnupdate.setvalue(
                                t_prilictypeobjid,
                                api.pkg_configquery.columndefidforname(
                                    'o_PrimaryLicenseType',
                                    'IsAutoTransfer'),
                                'Y');
                            -- Copy stored details from License Type object from Lic to Primary License Type Job of App
                            pkg_copy.copystoredobjectdetails(
                                c_2.lictypejobid,
                                t_prilictypeobjid);

                            -- relate the new Primary License Type job to the Application
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_Application',
                                        'PrimaryLicenseType'),
                                    a_appobjectid,
                                    t_prilictypeobjid);
                            -- relate the new Primary License Type Job to the License Type Category object.
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'o_PrimaryLicenseType',
                                        'LicTypeCatPrimary'),
                                    t_prilictypeobjid,
                                    c_2.ltcatobjid);

                            -- Look for existing Secondary license types associated with the existing License Type. Copy.
                            FOR c_sec
                                IN (SELECT r.toobjectid     secltobjid -- 04.21 adding logic copy Secondary LT count
                                                                      ,
                                           r.relationshipid licrelltsecltc
                                      FROM api.relationships r
                                     WHERE r.fromobjectid = c_2.lictypejobid
                                       AND r.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'j_LicenseType',
                                               'LicTypeCatSecondary'))
                            LOOP               -- SecondaryLicenseTypeCategory
                                -- Relate the new Primary License Type Job to the Secondary License Type Category object.
                                t_newrelobjectid   :=
                                    api.pkg_relationshipupdate.new(
                                        api.pkg_configquery.endpointidforname(
                                            'o_PrimaryLicenseType',
                                            'LicTypeCatSecondary'),
                                        t_prilictypeobjid,
                                        c_sec.secltobjid);

                                -- Copy License Type count
                                pkg_copy.copystoredobjectdetails(
                                    c_sec.licrelltsecltc,
                                    t_newrelobjectid);

                                -- Set the Is Transferred detail
                                api.pkg_columnupdate.setvalue(
                                    t_newrelobjectid,
                                    'IsAutoTransfer',
                                    'Y');

                                FOR c_dup
                                    IN (SELECT d.duplicateid objectid
                                          FROM sitespecific.duplicate_t d
                                         WHERE d.licensetypejobid =
                                               c_2.lictypejobid
                                           AND d.licensetypecategoryobjectid =
                                               c_sec.secltobjid)
                                LOOP
                                    --Copy duplicate objects to application
                                    t_newobjectid   :=
                                        api.pkg_objectupdate.new(
                                            api.pkg_configquery.objectdefidforname(
                                                'o_Duplicate'));

                                    --  Copy the Duplicate Details
                                    --note that it is important to set the license type category object id before anything else otherwise it errors.
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'LicenseTypeCategoryObjectID',
                                        api.pkg_columnquery.VALUE(
                                            c_dup.objectid,
                                            'LicenseTypeCategoryObjectID'));
                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'Description',
                                        api.pkg_columnquery.VALUE(
                                            c_dup.objectid,
                                            'Description'));
                                    pkg_copy.copystoredobjdetailsexception(
                                        c_dup.objectid,
                                        t_newobjectid,
                                        'IssueDate,LicenseTypeJobId');

                                    api.pkg_columnupdate.setvalue(
                                        t_newobjectid,
                                        'PrimaryLicenseTypeObjectID',
                                        t_prilictypeobjid);
                                END LOOP;
                            END LOOP; -- Secondary LT to License Type Category
                        EXCEPTION
                            WHEN OTHERS THEN
                                api.pkg_errors.raiseerror(
                                    -20000,
                                       ' . ERROR copying License Type to Application. '
                                    || SQLERRM);
                        END; -- Create and relate License Types to Application, and License Type Category
                    ELSE
                        NULL;
                    END IF;
                END LOOP;                -- License Types on existing License.
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           ' . ERROR License Status could not be determined.'
                        || SQLERRM);
                WHEN OTHERS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           ' . ERROR determining License Types on existing License'
                        || SQLERRM);
            END; --   END License Types copied for Apps involving License Type Exchange

            --  set PriorityCopyProcedureHasRun to Y
            api.pkg_columnupdate.setvalue(
                a_appobjectid,
                api.pkg_configquery.columndefidforname(
                    'j_Application',
                    'PriorityCopyProcedureHasRun'),
                'Y');
        END IF;                                       -- if change or transfer
    END;                          -- procedure CopyPriorityLicDetailsToApp end
END pkg_copy_license;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_COPY_LICENSE TO POSSEEXTENSIONS;
