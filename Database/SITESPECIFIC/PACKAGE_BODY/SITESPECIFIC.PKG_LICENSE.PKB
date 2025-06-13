CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_LICENSE"
IS
    -- **************************************************************************
    -- File:        PKG_LICENSE.pkb
    -- Author:      CX
    --
    -- $Rev: 10 $
    -- $Date: 2018-08-20 10:49:39 -0700 (Mon, 20 Aug 2018) $
    -- Last Changed By:  $Author: tlord $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- 03/16/2020 TJL  20884  Added check for Membership Transfer in procedure
    --                          "withdrawlicensetypes"
    -- 01/31/2023 PK          Changed copyassigninvefntocondinv,copyconductinvefntocloseinv to resolve problem after Objectid have been moved to new gap
    -- 12/10/2023 PK          Created PROCEDURE generateCreateCatererEventAuthextfilenum
    -- 12/10/2023 PK          Created PROCEDURE copycreatecaterertoIssuecaterer
    
    -- **************************************************************************

    /*------------------------------------------------------------------------*
     -- ActivatePendingSecondaryLTs()
     -- Upon completion of the Issue License Process
     -- this will activate all Pending secondary license types.
     *------------------------------------------------------------------------*/

    PROCEDURE activatependingsecondarylts(a_processid     udt_id,
                                          a_asofdate      DATE,
                                          a_jobid         udt_id)
    IS
        t_readytoissuedate   DATE;
    BEGIN
        t_readytoissuedate   :=
            api.pkg_columnquery.datevalue(a_processid, 'ReadyToIssueDate');

        IF api.pkg_columnquery.VALUE(a_processid, 'AddPermitLTProcessId')
               IS NOT NULL THEN
            FOR c
                IN (SELECT slt.relationshipid,
                           slt.status,
                           slt.licensetypecount,
                           llt.licensetypejobid,
                           slt.licensetypecategoryobjectid,
                           d.objectid
                      FROM query.r_licenselicensetype  llt
                           JOIN query.r_licensetypeltcatsecondary slt
                               ON slt.licensetypejobid = llt.licensetypejobid
                           JOIN sitespecific.duplicate_t t
                               ON t.relationshipid = slt.relationshipid
                           JOIN query.o_duplicate d
                               ON d.objectid = t.duplicateid
                     WHERE llt.licensejobid = a_jobid
                       AND d.status = 'PENDING')
            LOOP
                --Set Status to Active
                --      api.pkg_columnupdate.SetValue(c.relationshipid, 'Status', 'ACTIVE');
                --Removed for HotFix22Part5 Status Change on Completion of the License Batch job.

                -- Set the batch flags
                pkg_batchtype.setbatchflags(
                    a_lictypejobid => c.relationshipid,
                    a_includeinproducelicensebatch => 'Y',
                    a_includeindailybatch => 'Y');

                -- Set the Ready to Issue Date on the secondary license types
                --api.pkg_columnupdate.SetValue(c.relationshipid,'ReadyToIssueDate',t_ReadytoIssueDate);
                api.pkg_columnupdate.setvalue(c.objectid,
                                              'ReadyToIssueDate',
                                              t_readytoissuedate);
                -- Set the type of issueance on the secondary license types
                --api.pkg_columnupdate.SetValue(c.relationshipid,'TypeOfIssuance', 'DOR');
                api.pkg_columnupdate.setvalue(c.objectid,
                                              'ReadyToIssueDate',
                                              t_readytoissuedate);
                api.pkg_columnupdate.setvalue(c.objectid,
                                              'IssueDate',
                                              SYSDATE);
                api.pkg_columnupdate.setvalue(c.objectid,
                                              'TypeOfIssuance',
                                              'DOR');
                -- Set the type of issuance on the Duplicates
                /* for c_dup in (select d.duplicateid ObjectId
                                 from sitespecific.duplicate_T d
                                where d.LicenseTypeJobid = c.LicenseTypeJobid
                                  and d.LicenseTypeCategoryObjectID = c.LicenseTypeCategoryObjectId
                                  and d.relationshipid = c.relationshipid) loop
                   api.pkg_columnupdate.SetValue(c_dup.objectid, 'IssueDate', sysdate);
                   api.pkg_columnupdate.SetValue(c_dup.objectid, 'ReadyToIssueDate', t_ReadytoIssueDate);
                   api.pkg_columnupdate.SetValue(c_dup.objectid, 'TypeOfIssuance', 'DOR');

                 end loop;*/

                --Maintain Dups on post verify
                api.pkg_columnupdate.setvalue(
                    c.licensetypejobid,
                    'dup_IncludeInProduceLicBatchSe',
                    'Y');
            END LOOP;
        END IF;
    END activatependingsecondarylts;

    -------------------------------------------------
    -- SetBatchFlagsIssueLicenseType()
    -- Called on the Issue out come of IssueLicenseType
    -------------------------------------------------

    PROCEDURE setbatchflagsissuelicensetype(a_processid     udt_id,
                                            a_asofdate      DATE)
    IS
        t_lictypejobid       udt_id;
        t_secodaryrelid      udt_id;
        t_readytoissuedate   DATE;
    BEGIN
        t_readytoissuedate   :=
            api.pkg_columnquery.datevalue(a_processid, 'ReadyToIssueDate');

        t_lictypejobid   :=
            api.pkg_columnquery.numericvalue(a_processid, 'JobId');

        IF api.pkg_columnquery.VALUE(t_lictypejobid, 'StatusName') = 'PEND' THEN
            pkg_batchtype.setbatchflags(
                a_lictypejobid => t_lictypejobid,
                a_includeinproducelicensebatch => 'Y',
                a_includeindailybatch => 'Y');

            -- Set the Ready to Issue Date on the primary license type
            api.pkg_columnupdate.setvalue(t_lictypejobid,
                                          'ReadyToIssueDate',
                                          t_readytoissuedate);
        END IF;

        --loop through secondaries associated with License Type and set batch flags

        FOR c
            IN (SELECT slt.relationshipid,
                       slt.licensetypecategoryobjectid,
                       slt.licensetypejobid
                  FROM query.r_licensetypeltcatsecondary slt
                 WHERE slt.licensetypejobid = t_lictypejobid
                   AND slt.status = 'PENDING')
        LOOP
            pkg_batchtype.setbatchflags(
                a_lictypejobid => c.relationshipid,
                a_includeinproducelicensebatch => 'Y',
                a_includeindailybatch => 'Y');

            -- Set the Ready to Issue Date on the secondary license types
            api.pkg_columnupdate.setvalue(c.relationshipid,
                                          'ReadyToIssueDate',
                                          t_readytoissuedate);

            -- Set the type of issueance on the secondary license types
            api.pkg_columnupdate.setvalue(c.relationshipid,
                                          'TypeOfIssuance',
                                          'DOR');

            -- Set the type of issuance on the Duplicates
            FOR c_dup
                IN (SELECT d.duplicateid objectid
                      FROM sitespecific.duplicate_t d
                     WHERE d.licensetypejobid = c.licensetypejobid
                       AND d.licensetypecategoryobjectid =
                           c.licensetypecategoryobjectid
                       AND d.relationshipid = c.relationshipid)
            LOOP
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
        END LOOP;

        --Maintain Dups on post verify
        api.pkg_columnupdate.setvalue(t_lictypejobid,
                                      'dup_IncludeInProduceLicBatchSe',
                                      'Y');
    END setbatchflagsissuelicensetype;

    /*----------------------------------------------------------------------
    -- Create 150 Day Reminder
    ----------------------------------------------------------------------*/
    PROCEDURE create150dayreminder(a_objectid udt_id, a_asofdate DATE)
    IS
        t_reminderid      udt_id;
        t_reminderdefid   udt_id;
        t_relid           udt_id;
    BEGIN
        SELECT od.objectdefid
          INTO t_reminderdefid
          FROM api.objectdefs od
         WHERE od.name = 'o_Reminder';

        t_reminderid   := api.pkg_objectupdate.new(t_reminderdefid);

        t_relid        :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('o_Reminder',
                                                      'Issue150DayLicense'),
                t_reminderid,
                a_objectid);

        api.pkg_columnupdate.setvalue(
            t_reminderid,
            'ReminderDate',
            api.pkg_columnquery.VALUE(a_objectid, 'ExpirationDate'));

        api.pkg_columnupdate.setvalue(
            t_reminderid,
            'ReminderDescription',
            'Reevaluate this license for SLMS Revocation');
    END create150dayreminder;

    /*----------------------------------------------------------------------
    -- Create Manage Priority Application External File Number
    -- Format is CountyCode-YYYY-[000]
    ----------------------------------------------------------------------*/
    PROCEDURE createmanagepriorityappfilenum(a_jobid udt_id, a_asofdate DATE)
    IS
        t_externalfilenum   VARCHAR2(40);
        t_countycode        NUMBER;
        t_year              VARCHAR2(4);
        t_sequenceid        udt_id;
        t_sequence          NUMBER;
    BEGIN
        --Generate the Sequnce part of the file number
        BEGIN
            SELECT sequenceid
              INTO t_sequenceid
              FROM api.sequences
             WHERE description = 'Manage Priority Applications';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'Manage Priority Applications sequence not found.');
        END;

        t_sequence     :=
            api.pkg_utils.generateexternalfilenum('[000]', t_sequenceid);

        --Get the County Code
        t_countycode   := api.pkg_columnquery.VALUE(a_jobid, 'County');

        --Get the Year
        t_year         := TO_CHAR(SYSDATE, 'YYYY');

        --Create the External File Number
        t_externalfilenum   :=
               t_countycode
            || '-'
            || t_year
            || '-'
            || LPAD(t_sequence, 3, '000');

        --Generate the External File Number on the Job
        api.pkg_objectupdate.setexternalfilenum(a_jobid, t_externalfilenum);
    END createmanagepriorityappfilenum;

    ----------------------------------------------------------------------------------------------------
    --  GenerateAppExternalFileNum() -- PUBLIC
    --  This generates the external file number on the Application Job
    ----------------------------------------------------------------------------------------------------
    PROCEDURE generateappexternalfilenum(a_objectid udt_id, a_asofdate DATE)
    IS
        t_sequenceid        udt_id;
        t_externalfilenum   VARCHAR2(40);
        t_applicationtype   VARCHAR2(100);
    BEGIN
        t_applicationtype   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ApplicationType');

        IF t_applicationtype IN ('Original', 'Transfer') THEN
            BEGIN
                SELECT s.sequenceid
                  INTO t_sequenceid
                  FROM api.sequences s
                 WHERE s.description = 'License Number';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'Sequence with description "License Number" cannot be found.');
            END;

            t_externalfilenum   :=
                api.pkg_utils.generateexternalfilenum('[000000]-{YYMMDD}',
                                                      t_sequenceid);

            api.pkg_jobupdate.setexternalfilenum(a_objectid,
                                                 t_externalfilenum);
        END IF;
    END generateappexternalfilenum;


    ----------------------------------------------------------------------------------------------------
    --  GenerateAssignLicenseInvExternalFileNum() -- PUBLIC
    --  This generates the external file number on the Assign License Investigation (which is copied to the Conduct).
    ----------------------------------------------------------------------------------------------------
    PROCEDURE generateassigninvextfilenum(a_objectid udt_id, a_asofdate DATE)
    IS
        t_sequenceid        udt_id;
        t_externalfilenum   VARCHAR2(40);
        t_officeid          NUMBER;
        t_officenameabrv    VARCHAR2(5);
    BEGIN
        SELECT s.sequenceid
          INTO t_sequenceid
          FROM api.sequences s
         WHERE s.description = 'Investigation Sequence';

        --    exception when NO_DATA_FOUND then
        --    api.pkg_errors.RaiseError(-20000, 'Sequence with description "Investigation Sequence" cannot be found.');

        t_officeid   :=
            api.pkg_columnquery.VALUE(a_objectid,
                                      'InvestigationOfficeObjectId');

        t_officenameabrv   :=
            api.pkg_columnquery.VALUE(t_officeid, 'OfficeNameAbbreviation');

        t_externalfilenum   :=
            api.pkg_utils.generateexternalfilenum(
                t_officenameabrv || '-' || '[90000000]',
                t_sequenceid);

        api.pkg_processupdate.setexternalfilenum(a_objectid,
                                                 t_externalfilenum);
    END generateassigninvextfilenum;


    ----------------------------------------------------------------------------------------------------
    --  CopyAssignInvEFNToCondInv() -- PUBLIC
    --  Copies external file number on the Assign License/Admin Investigation process to Conduct License/Admin Investigation process.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE copyassigninvefntocondinv(a_objectid      udt_id,
                                        a_asofdate      DATE,
                                        a_jobid         udt_id)
    IS
        t_conductinvprocessid   NUMBER;
        t_externalfilenum       VARCHAR(40);
        t_processtypeid         udt_id;
    BEGIN
        SELECT CASE
                   WHEN p.processtypeid =
                        api.pkg_objectdefquery.idforname(
                            'p_AssignAdminInvestigation') THEN
                       api.pkg_objectdefquery.idforname(
                           'p_ConductAdminInvestigation')
                   ELSE
                       api.pkg_objectdefquery.idforname(
                           'p_ConductLicenseInvestigation')
               END
                   processtypeid
          INTO t_processtypeid
          FROM api.processes p
         WHERE p.processid = a_objectid;

        -- 01/31/2023 PK          Changed Max(Processid) to resolve problem after Objectid have been moved to new gap     
        SELECT p2.PROCESSID
          INTO t_conductinvprocessid
          FROM 
            (SELECT MAX (p.createddate) Maxcreateddate
                 FROM api.processes p
                 WHERE jobid = a_jobid
                 AND processtypeid IN t_processtypeid) x
                    JOIN api.processes p2 ON p2.CREATEDDATE = x.Maxcreateddate
                     WHERE p2.jobid = a_jobid;

        t_externalfilenum   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ExternalFileNum');

        api.pkg_processupdate.setexternalfilenum(t_conductinvprocessid,
                                                 t_externalfilenum);
    END copyassigninvefntocondinv;


    ----------------------------------------------------------------------------------------------------
    --  CopyConductInvEFNToCloseInv() -- PUBLIC
    --  Copies external file number on the Conduct License/Admin Investigation process to Close Investigation process.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE copyconductinvefntocloseinv(a_objectid      udt_id,
                                          a_asofdate      DATE,
                                          a_jobid         udt_id)
    IS
        t_closeinvprocessid   NUMBER;
        t_externalfilenum     VARCHAR(40);
        t_processtypeid       udt_id;
    BEGIN
        t_processtypeid   :=
            api.pkg_configquery.objectdefidforname('p_CloseInvestigation');

       -- 01/31/2023 PK          Changed Max(Processid) to resolve problem after Objectid have been moved to new gap
 
            SELECT p2.PROCESSID
             INTO t_closeinvprocessid
              FROM (SELECT MAX (p.createddate) Maxcreateddate
                        FROM api.processes p
                        WHERE jobid = a_jobid AND processtypeid IN t_processtypeid) x
                        JOIN api.processes p2 ON p2.CREATEDDATE = x.Maxcreateddate
                        WHERE p2.jobid = a_jobid;

        t_externalfilenum   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ExternalFileNum');

        api.pkg_processupdate.setexternalfilenum(t_closeinvprocessid,
                                                 t_externalfilenum);
    END copyconductinvefntocloseinv;

    ----------------------------------------------------------------------------------------------------
    --  IssueBeerKegTag() -- PUBLIC
    -- Runs on completion of the Issue Beer Keg process. Created the BKT fee, and writes out the tags
    -- to a table for searching.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE issuebeerkegtags(a_objectid udt_id, a_asofdate DATE)
    AS
        t_alpha               VARCHAR2(1);
        t_starttag            NUMBER;
        t_count               NUMBER;
        t_receiptbooks        NUMBER;
        t_jobid               NUMBER;
        t_ltcode              VARCHAR2(3);
        t_populationapplies   VARCHAR2(1);
        t_populationrange     VARCHAR2(100);
    BEGIN
        t_alpha   :=
            SUBSTR(api.pkg_columnquery.VALUE(a_objectid, 'StartTag'), 1, 1);
        t_starttag   :=
            SUBSTR(api.pkg_columnquery.VALUE(a_objectid, 'StartTag'), 2);
        t_count   := api.pkg_columnquery.numericvalue(a_objectid, 'Count');
        t_jobid   := api.pkg_columnquery.VALUE(a_objectid, 'JobId');
        t_receiptbooks   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ReceiptBooks');

        IF t_alpha NOT BETWEEN 'A' AND 'Z' THEN
            api.pkg_errors.raiseerror(
                -20000,
                'The first letter of the tag must be alphabetic.');
        END IF;

        -- Write rows to beer keg tag table
        FOR c IN 1 .. t_count * 100
        LOOP
            --api.pkg_Errors.RaiseError(-20000, t_Alpha||(t_StartTag+(c-1)));
            INSERT INTO beerkegtags_t
                     VALUES (t_alpha || TO_CHAR(t_starttag + (c - 1)),
                             a_objectid);
        END LOOP;

        -- Create fees
        SELECT ltc.licensetypecode, ltc.populationapplies
          INTO t_ltcode, t_populationapplies
          FROM query.r_beerkegtaglicensetype  r
               JOIN query.o_licensetypecategory ltc
                   ON ltc.objectid = r.licensetypecategoryobjectid
         WHERE r.issuebeerkegtagprocessid = a_objectid;

        IF t_populationapplies = 'Y' THEN
            SELECT a.populationrange
              INTO t_populationrange
              FROM query.j_license  l
                   JOIN query.r_licenseaddrpremises r
                       ON r.licensejobid = l.jobid
                   JOIN query.o_address a ON a.objectid = r.premisesobjectid
             WHERE l.jobid = t_jobid;
        END IF;

        -- Create BKT Fees
        pkg_fees.createsimplefee(a_objectid,
                                 SYSDATE,
                                 t_jobid,
                                 'BKT',
                                 t_count,
                                 t_ltcode,
                                 t_populationrange);

        IF t_receiptbooks IS NOT NULL
       AND t_receiptbooks > 0 THEN
            -- Create BKR Fees
            pkg_fees.createsimplefee(a_objectid,
                                     SYSDATE,
                                     t_jobid,
                                     'BKR',
                                     t_receiptbooks,
                                     t_ltcode,
                                     t_populationrange);
        END IF;
    END issuebeerkegtags;

    ----------------------------------------------------------------------------------------------------
    --  ReinstateLicense() -- PUBLIC
    -- Create and completes Reinstate License Type process on the related license types.
    -- The procedure also inserts the Reinstate License type process for any Primary License Types
    -- which are not in AutoRev or RevPending but that DO have Secondary License Types in those statuses.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE reinstatelicense(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_jobid         udt_id,
                               a_overridebalanceowingcheck CHAR)
    IS
        t_newprocessid   udt_id;
        t_outcome        VARCHAR2(400)
            := api.pkg_columnquery.VALUE(a_objectid, 'Outcome');
        t_owerenfees     NUMBER;
    BEGIN
        FOR c
            IN (SELECT DISTINCT lt.jobid ltjobid
                  FROM query.r_licenselicensetype  llt
                       JOIN query.j_licensetype lt
                           ON lt.jobid = llt.licensetypejobid
                       LEFT JOIN query.r_licensetypeltcatsecondary slt
                           ON slt.licensetypejobid = lt.jobid
                 WHERE llt.licensejobid = a_jobid
                   AND (lt.statusname IN ('AUTREV', 'REVPEN')
                     OR slt.status IN ('AUTO REVOKED', 'REV PENDING')))
        LOOP
            IF a_overridebalanceowingcheck = 'Y' THEN
                t_newprocessid   :=
                    api.pkg_processupdate.new(
                        c.ltjobid,
                        api.pkg_configquery.objectdefidforname(
                            'p_ReinstateLicenseType'),
                        NULL,
                        NULL,
                        NULL,
                        NULL);

                api.pkg_columnupdate.setvalue(t_newprocessid,
                                              'OverrideBalanceOwingCheck',
                                              a_overridebalanceowingcheck);

                api.pkg_processupdate.complete(t_newprocessid, t_outcome);


                -- for the license type job, set the detail Reinstate
                api.pkg_columnupdate.setvalue(c.ltjobid, 'Reinstate', 'Y');
            ELSE                         -- check for outstanding renewal fees
                BEGIN
                    -- RyanL: Changed fee calculation for performance (PIP Task 8.5)
                    SELECT SUM((  f.amount
                                + NVL((SELECT SUM(amount)
                                         FROM api.feetransactions ft
                                        WHERE ft.feeid = f.feeid),
                                      0)))
                      INTO t_owerenfees
                      FROM api.fees f
                     WHERE f.jobid IN (a_jobid, c.ltjobid)
                       AND f.glaccountid IN
                               (SELECT g.glaccountid
                                  FROM api.glaccounts g
                                 WHERE g.glaccount IN
                                           ('REN', 'REN50', 'REN100'));
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                END;

                IF t_owerenfees > 0 THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'Outstanding Fee balance is preventing Reinstatement.');
                ELSE
                    t_newprocessid   :=
                        api.pkg_processupdate.new(
                            c.ltjobid,
                            api.pkg_configquery.objectdefidforname(
                                'p_ReinstateLicenseType'),
                            NULL,
                            NULL,
                            NULL,
                            NULL);

                    api.pkg_columnupdate.setvalue(
                        t_newprocessid,
                        'OverrideBalanceOwingCheck',
                        a_overridebalanceowingcheck);

                    api.pkg_processupdate.complete(t_newprocessid, t_outcome);

                    api.pkg_columnupdate.setvalue(c.ltjobid,
                                                  'Reinstate',
                                                  'Y');
                END IF;
            END IF;
        END LOOP;
    END reinstatelicense;


    ----------------------------------------------------------------------------------------------------
    --  AutoHold()
    --  Create a hold related to the application upon completion of the enter application.
    --  The mandatory columns are defaulted but can be changed with the congifuration window.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE autohold(a_objectid      udt_id,
                       a_asofdate      DATE,
                       a_jobid         udt_id,
                       a_holdtype      VARCHAR2,
                       a_holdcomment   VARCHAR2)
    IS
        t_holdobjid     udt_id;
        t_newrelid      udt_id;
        t_holdtype      VARCHAR2(60);
        t_holdcomment   VARCHAR2(4000);
    BEGIN
        IF a_holdtype IS NULL THEN
            t_holdtype   := 'FORM 220';
        ELSE
            t_holdtype   := a_holdtype;
        END IF;

        IF a_holdcomment IS NULL THEN
            t_holdcomment   := 'SYSTEM GENERATED HOLD.';
        ELSE
            t_holdcomment   := a_holdcomment;
        END IF;

        t_holdobjid   :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('o_Hold'));
        api.pkg_columnupdate.setvalue(t_holdobjid,
                                      'HoldCreatedDate',
                                      SYSDATE);
        api.pkg_columnupdate.setvalue(t_holdobjid, 'HoldType', t_holdtype);
        api.pkg_columnupdate.setvalue(t_holdobjid,
                                      'HoldComment',
                                      t_holdcomment);
        t_newrelid   :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('j_Application',
                                                      'Hold'),
                a_jobid,
                t_holdobjid);
    END autohold;

    ---------------------------------------------------------------------------
    -- MasterP12Rel() -- PUBLIC
    -------------------------------------------------------------------------*/
    PROCEDURE masterp12rel(a_objectid         udt_id,
                           a_endpointid       udt_id,
                           a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_objectid   udt_id;
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        BEGIN
            SELECT ml.jobid
              INTO t_objectid
              FROM query.j_license  l
                   JOIN query.r_licenseprimaryp12legalentity lple
                       ON lple.licensejobid = l.jobid
                   JOIN query.r_licenseprimaryp12legalentity lmple
                       ON lmple.primayrp12leobjectid =
                          lple.primayrp12leobjectid
                   JOIN query.j_license ml ON ml.jobid = lmple.licensejobid
             WHERE l.jobid = a_objectid
               AND ml.thislicenseisp12master = 'Y';

            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(1)   := api.udt_object(t_objectid);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;
    END masterp12rel;

    /*----------------------------------------------------------------------------------------------------
      --  WithdrawLicenseTypes()     --Public
      --  This procedure will be called on change of the  boolean and will set all
      -- of the Issue booleans in the grid based.
      ----------------------------------------------------------------------------------------------------*/

    PROCEDURE withdrawlicensetypes(a_objectid      udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id)
    IS
        t_withdrawapp    VARCHAR2(50);
        t_changestatus   udt_id;
    BEGIN
        FOR primary
            IN (SELECT r.toobjectid prilictypeobjid
                  FROM api.relationships  r
                       JOIN api.relationships wlt
                           ON wlt.fromobjectid = a_objectid  -- a_ProcessObjId
                          AND wlt.toobjectid = r.toobjectid
                          AND wlt.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'p_WithdrawApplication',
                                  'PrimaryLicenseType')
                 WHERE r.fromobjectid = a_jobid                --a_AppObjectId
                   AND r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_Application',
                           'PrimaryLicenseType')
                   AND api.pkg_columnquery.VALUE(wlt.relationshipid,
                                                 'Withdraw') =
                       'Y'
                   AND api.pkg_columnquery.VALUE(wlt.toobjectid, 'Status') IN
                           ('NEW', 'PENDING'))
        LOOP
            api.pkg_columnupdate.setvalue(primary.prilictypeobjid,
                                          'Status',
                                          'WITHDRAWN');

            FOR secondary
                IN (SELECT                                    --Secondary loop
                           r.toobjectid        seclictypecatobjid,
                           r.relationshipid    secondarylicensetypecatrelid,
                           wslt.relationshipid withdrawsltrelid
                      FROM api.relationships  r
                           JOIN api.relationships wslt
                               ON wslt.fromobjectid = a_objectid
                              AND wslt.toobjectid = r.toobjectid
                              AND wslt.endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'p_WithdrawApplication',
                                      'LicTypeCatSecondary')
                     WHERE r.fromobjectid = primary.prilictypeobjid
                       AND r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'o_PrimaryLicenseType',
                               'LicTypeCatSecondary')
                       AND api.pkg_columnquery.VALUE(wslt.relationshipid,
                                                     'Withdraw') =
                           'Y'
                       AND api.pkg_columnquery.VALUE(r.relationshipid,
                                                     'SStatus') IN
                               ('NEW', 'PENDING'))
            LOOP
                api.pkg_columnupdate.setvalue(
                    secondary.secondarylicensetypecatrelid,
                    'SStatus',
                    'WITHDRAWN');
                api.pkg_columnupdate.setvalue(secondary.withdrawsltrelid,
                                              'Status',
                                              'WITHDRAWN');
            END LOOP;
        END LOOP;

        FOR missedsecondary
            IN (SELECT                                        --Secondary loop
                       r.toobjectid        seclictypecatobjid,
                       r.relationshipid    secondarylicensetypecatrelid,
                       wslt.relationshipid withdrawsltrelid
                  FROM api.relationships  ap
                       JOIN api.relationships r
                           ON r.fromobjectid = ap.toobjectid
                          AND r.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'o_PrimaryLicenseType',
                                  'LicTypeCatSecondary')
                       JOIN api.relationships wslt
                           ON wslt.fromobjectid = a_objectid       --processId
                          AND wslt.toobjectid = r.toobjectid
                          AND wslt.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'p_WithdrawApplication',
                                  'LicTypeCatSecondary')
                 WHERE ap.fromobjectid = a_jobid                       --appid
                   AND ap.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_Application',
                           'PrimaryLicenseType')
                   AND api.pkg_columnquery.VALUE(wslt.relationshipid,
                                                 'Withdraw') =
                       'Y'
                   AND api.pkg_columnquery.VALUE(r.relationshipid, 'SStatus') !=
                       'ISSUED')
        LOOP
            api.pkg_columnupdate.setvalue(
                missedsecondary.secondarylicensetypecatrelid,
                'SStatus',
                'WITHDRAWN');
            api.pkg_columnupdate.setvalue(missedsecondary.withdrawsltrelid,
                                          'Status',
                                          'WITHDRAWN');
        END LOOP;

        -- Added 'MissedPendingSecondary'to resolve Issue CX # 2503 (ABC # 1978) where the Pending secondaries were not withdrwaing via W'ithdraw Application' process -- Gurpreet Aug 2013.
        FOR missedpendingsecondary
            IN (SELECT o.objectid        pendingsltobjectid,
                       p.objectid        withdrawapplicationprocessid,
                       r3.relationshipid priltltcatsecondaryrelid
                  FROM query.p_withdrawapplication  p
                       JOIN query.r_withdrawapplicltcatsecondary r
                           ON r.withdrawappprocessid = p.processid -- a_ObjectId --processId
                       JOIN query.o_pendingsecondarylicensetype o
                           ON o.objectid = r.pendingsltobjectid
                       -- join query.j_application jap on jap.JobID = p.JobID
                       JOIN query.r_appprimarylicensetype r2
                           ON r2.applicationobjectid = a_jobid --appid  --p.JobID  --jap.ObjectID
                       JOIN query.r_priltltcatsecondary r3
                           ON r3.primarylicensetypeobjectid =
                              r2.licensetypeobjectid
                 WHERE p.processid = a_objectid                    --processId
                   AND api.pkg_columnquery.VALUE(o.objectid, 'Withdraw') =
                       'Y'
                   AND api.pkg_columnquery.VALUE(o.objectid, 'Status') !=
                       'ISSUED'
                   AND api.pkg_columnquery.VALUE(r3.relationshipid,
                                                 'SStatus') !=
                       'ISSUED'              -- Dynamic Detail on Relationship
                   AND api.pkg_columnquery.VALUE(o.objectid,
                                                 'LicenseTypeCode') =
                       api.pkg_columnquery.VALUE(r3.relationshipid,
                                                 'LicenseTypeCode'))
        LOOP
            api.pkg_columnupdate.setvalue(
                missedpendingsecondary.pendingsltobjectid,
                'Status',
                'WITHDRAWN');
            api.pkg_columnupdate.setvalue(
                missedpendingsecondary.priltltcatsecondaryrelid,
                'SStatus',
                'WITHDRAWN');                -- Dynamic Detail on Relationship
        END LOOP;

        --Check to see if the status should change.
        SELECT CASE
                   WHEN SUM(withdrawn) = SUM(total) THEN
                       'Withdrawn'
                   WHEN SUM(total) - SUM(withdrawn) = SUM(issued) THEN
                       'Issued'
                   WHEN SUM(issued) = 0
                    AND SUM(issuepending) > 0 THEN
                       'Pending'
                   WHEN SUM(issuepending) - SUM(withdrawn) > 0 THEN
                       'Pending'
                   ELSE
                       'UNKNOWN'
               END
                   status
          --,Sum(PENDING), SUM(WITHDRAWN), SUM(ISSUED), SUM(TOTAL)
          INTO t_withdrawapp
          FROM (SELECT SUM(
                           DECODE(
                               api.pkg_columnquery.VALUE(toobjectid,
                                                         'Status'),
                               'WITHDRAWN', 1,
                               0))
                           withdrawn,
                       SUM(
                           DECODE(
                               api.pkg_columnquery.VALUE(toobjectid,
                                                         'Issued'),
                               'Y', 1,
                               0))
                           issued,
                       SUM(
                           DECODE(
                               api.pkg_columnquery.VALUE(toobjectid,
                                                         'Issued'),
                               'N', 1,
                               0))
                           issuepending,
                       COUNT(toobjectid)
                           total
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_Application',
                           'PrimaryLicenseType')
                   AND r.fromobjectid = a_jobid   --1155155--1136157 --{JobId}
                UNION ALL
                SELECT SUM(
                           DECODE(
                               api.pkg_columnquery.VALUE(r2.relationshipid,
                                                         'SStatus'),
                               'WITHDRAWN', 1,
                               0))
                           withdrawn,
                       SUM(
                           DECODE(
                               api.pkg_columnquery.VALUE(r2.relationshipid,
                                                         'Issued'),
                               'Y', 1,
                               0))
                           issued,
                       SUM(
                           DECODE(
                               api.pkg_columnquery.VALUE(r2.relationshipid,
                                                         'Issued'),
                               'N', 1,
                               0))
                           issuepending,
                       COUNT(r2.relationshipid)
                           total
                  FROM api.relationships  r1
                       JOIN api.relationships r2
                           ON r2.fromobjectid = r1.toobjectid
                 WHERE r1.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_Application',
                           'PrimaryLicenseType')
                   AND r2.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'o_PrimaryLicenseType',
                           'LicTypeCatSecondary')
                   AND r1.fromobjectid = a_jobid           --1155155 --{JobId}
                                                );


        IF t_withdrawapp IN ('Withdrawn', 'Issued') THEN
            t_changestatus   :=
                api.pkg_processupdate.new(
                    a_jobid,
                    api.pkg_configquery.objectdefidforname('p_ChangeStatus'),
                    'System Generated.',
                    NULL,
                    NULL,
                    NULL);
            api.pkg_processupdate.complete(t_changestatus, t_withdrawapp);
        --
        -- For Stock Transfers, check that the Withdrawn is set to N ------------------------
        -- This is for where the Withdraw checkbox is not available or it is set to N
        ELSIF t_withdrawapp IN ('Pending')
          AND (api.pkg_columnquery.VALUE(a_jobid, 'StockTransfer') = 'Y' OR
               -- 03/16/2020 TJL 20884 Added check for Membership Transfer
               api.pkg_columnquery.VALUE(a_jobid, 'MembershipTransfer') = 'Y') THEN
            -- this creates a process entry called "Change Status"
            t_changestatus   :=
                api.pkg_processupdate.new(
                    a_jobid,
                    api.pkg_configquery.objectdefidforname('p_ChangeStatus'),
                    'System Generated.',
                    NULL,
                    NULL,
                    NULL);
            api.pkg_processupdate.complete(t_changestatus, 'Withdrawn');

            -- this keeps the Actives status  (otherwise it would change it to Withdrawn)
            FOR keep_primary_active_status
                IN (SELECT r.toobjectid prilictypeobjid
                      FROM api.relationships  r
                           JOIN api.relationships wlt
                               ON wlt.fromobjectid = a_objectid -- a_ProcessObjId
                              AND wlt.toobjectid = r.toobjectid
                              AND wlt.endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'p_WithdrawApplication',
                                      'PrimaryLicenseType')
                     WHERE r.fromobjectid = a_jobid            --a_AppObjectId
                       AND r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'PrimaryLicenseType')
                       AND api.pkg_columnquery.VALUE(wlt.relationshipid,
                                                     'Withdraw') =
                           'N')
            -- and api.pkg_columnquery.value(wlt.ToObjectId, 'Status') in ('ACTIVE' ))
            LOOP
                api.pkg_columnupdate.setvalue(
                    keep_primary_active_status.prilictypeobjid,
                    'Status',
                    'ACTIVE');

                --
                FOR keep_secomdary_active_status
                    IN (SELECT                                --Secondary loop
                               r.toobjectid        seclictypecatobjid,
                               r.relationshipid    secondarylicensetypecatrelid,
                               wslt.relationshipid withdrawsltrelid
                          FROM api.relationships  r
                               JOIN api.relationships wslt
                                   ON wslt.fromobjectid = a_objectid
                                  AND wslt.toobjectid = r.toobjectid
                                  AND wslt.endpointid =
                                      api.pkg_configquery.endpointidforname(
                                          'p_WithdrawApplication',
                                          'LicTypeCatSecondary')
                         WHERE r.fromobjectid =
                               keep_primary_active_status.prilictypeobjid
                           AND r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_PrimaryLicenseType',
                                   'LicTypeCatSecondary')
                           AND api.pkg_columnquery.VALUE(wslt.relationshipid,
                                                         'Withdraw') =
                               'N')
                -- and api.pkg_columnquery.value(r.RelationshipId, 'SStatus') in ('NEW', 'PENDING'))
                LOOP
                    api.pkg_columnupdate.setvalue(
                        keep_secomdary_active_status.secondarylicensetypecatrelid,
                        'SStatus',
                        'ACTIVE');
                    api.pkg_columnupdate.setvalue(
                        keep_secomdary_active_status.withdrawsltrelid,
                        'Status',
                        'ACTIVE');
                END LOOP;
            END LOOP;

            FOR keep_missedsec_active_status
                IN (SELECT                                    --Secondary loop
                           r.toobjectid        seclictypecatobjid,
                           r.relationshipid    secondarylicensetypecatrelid,
                           wslt.relationshipid withdrawsltrelid
                      FROM api.relationships  ap
                           JOIN api.relationships r
                               ON r.fromobjectid = ap.toobjectid
                              AND r.endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'o_PrimaryLicenseType',
                                      'LicTypeCatSecondary')
                           JOIN api.relationships wslt
                               ON wslt.fromobjectid = a_objectid   --processId
                              AND wslt.toobjectid = r.toobjectid
                              AND wslt.endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'p_WithdrawApplication',
                                      'LicTypeCatSecondary')
                     WHERE ap.fromobjectid = a_jobid                   --appid
                       AND ap.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'PrimaryLicenseType')
                       AND api.pkg_columnquery.VALUE(wslt.relationshipid,
                                                     'Withdraw') =
                           'N')
            --and api.pkg_columnquery.value(r.RelationshipId, 'SStatus') != 'ISSUED')
            LOOP
                api.pkg_columnupdate.setvalue(
                    keep_missedsec_active_status.secondarylicensetypecatrelid,
                    'SStatus',
                    'ACTIVE');
                api.pkg_columnupdate.setvalue(
                    keep_missedsec_active_status.withdrawsltrelid,
                    'Status',
                    'ACTIVE');
            END LOOP;

            -- Added 'MissedPendingSecondary'to resolve Issue CX # 2503 (ABC # 1978) where the Pending secondaries were not withdrwaing via W'ithdraw Application' process -- Gurpreet Aug 2013.
            FOR keep_missedpendsec_active
                IN (SELECT o.objectid        pendingsltobjectid,
                           p.objectid        withdrawapplicationprocessid,
                           r3.relationshipid priltltcatsecondaryrelid
                      FROM query.p_withdrawapplication  p
                           JOIN query.r_withdrawapplicltcatsecondary r
                               ON r.withdrawappprocessid = p.processid -- a_ObjectId --processId
                           JOIN query.o_pendingsecondarylicensetype o
                               ON o.objectid = r.pendingsltobjectid
                           -- join query.j_application jap on jap.JobID = p.JobID
                           JOIN query.r_appprimarylicensetype r2
                               ON r2.applicationobjectid = a_jobid --appid  --p.JobID  --jap.ObjectID
                           JOIN query.r_priltltcatsecondary r3
                               ON r3.primarylicensetypeobjectid =
                                  r2.licensetypeobjectid
                     WHERE p.processid = a_objectid                --processId
                       AND api.pkg_columnquery.VALUE(o.objectid, 'Withdraw') =
                           'N'
                       AND api.pkg_columnquery.VALUE(o.objectid, 'Status') !=
                           'ISSUED'
                       AND api.pkg_columnquery.VALUE(r3.relationshipid,
                                                     'SStatus') !=
                           'ISSUED')         -- Dynamic Detail on Relationship
            --and api.pkg_columnquery.value(o.ObjectID, 'LicenseTypeCode') = api.pkg_columnquery.value(r3.RelationshipID , 'LicenseTypeCode')
            LOOP
                api.pkg_columnupdate.setvalue(
                    keep_missedpendsec_active.pendingsltobjectid,
                    'Status',
                    'ACTIVE');
                api.pkg_columnupdate.setvalue(
                    keep_missedpendsec_active.priltltcatsecondaryrelid,
                    'SStatus',
                    'ACTIVE');               -- Dynamic Detail on Relationship
            END LOOP;
        ELSIF t_withdrawapp = 'UNKNOWN' THEN
            --To be removed for production
            api.pkg_errors.raiseerror(
                -20000,
                'Unknown error when trying to determine the status change.');
        END IF;
    END withdrawlicensetypes;

    /*----------------------------------------------------------------------------------------------------
      --  ReloadProcessGrids()     --Public
      --  Delete process and reload the process grids
      -- This applies for both the Issue License and Withdraw Application processes
      ----------------------------------------------------------------------------------------------------*/

    PROCEDURE reloadprocessgrids(a_objectid      udt_id,
                                 a_asofdate      DATE,
                                 a_jobid         udt_id)
    IS
        p_withdrawapp    VARCHAR2(1) := 'N';
        p_issuelicense   VARCHAR2(1) := 'N';
        t_jobid          udt_id;
    BEGIN
        FOR c
            IN (SELECT p.processid, p.processtypeid
                  FROM api.processes p
                 WHERE p.jobid = a_jobid
                   AND p.datecompleted IS NULL
                   AND p.processtypeid IN
                           (api.pkg_configquery.objectdefidforname(
                                'p_IssueLicense'),
                            api.pkg_configquery.objectdefidforname(
                                'p_WithdrawApplication')))
        LOOP
            api.pkg_processupdate.remove(c.processid);

            IF c.processtypeid =
               api.pkg_configquery.objectdefidforname('p_IssueLicense') THEN
                p_issuelicense   := 'Y';
            ELSIF c.processtypeid =
                  api.pkg_configquery.objectdefidforname(
                      'p_WithdrawApplication') THEN
                p_withdrawapp   := 'Y';
            END IF;
        END LOOP;

        IF p_withdrawapp = 'Y' THEN
            toolbox.pkg_workflow.createprocessesfromcheckboxes(
                a_jobid,
                SYSDATE,
                'JOB:VALUE:Y<>JOB:p_WithdrawApplication');
        END IF;

        IF p_issuelicense = 'Y' THEN
            toolbox.pkg_workflow.createprocessesfromcheckboxes(
                a_jobid,
                SYSDATE,
                'JOB:VALUE:Y<>JOB:p_IssueLicense');
        END IF;
    END reloadprocessgrids;

    PROCEDURE protestantselection(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_jobid         NUMBER,
                                  a_lastname      VARCHAR2,
                                  a_firstname     VARCHAR2,
                                  a_addressline1  VARCHAR2,
                                  a_city          VARCHAR2,
                                  a_state         VARCHAR2,
                                  a_zipcode       VARCHAR2,
                                  a_protestantreportingselection VARCHAR2)
    AS
        t_objects   api.udt_objectlist;
    BEGIN
        IF a_protestantreportingselection IS NOT NULL THEN
            t_objects   := api.udt_objectlist();
            -- Get the Protestants that are currently displayed on the job
            pkg_abcsearch.findprotestant(a_jobid,
                                         a_lastname,
                                         a_firstname,
                                         a_addressline1,
                                         a_city,
                                         a_state,
                                         a_zipcode,
                                         NULL,
                                         NULL,
                                         NULL,
                                         NULL,
                                         t_objects);

            -- Set the Selected for Reporting flag
            FOR c IN 1 .. t_objects.COUNT
            LOOP
                api.pkg_columnupdate.setvalue(t_objects(c).objectid,
                                              'SelectedForReporting',
                                              a_protestantreportingselection);
            END LOOP;

            api.pkg_columnupdate.removevalue(a_jobid,
                                             'ProtestantReportingSelection');
        END IF;
    END protestantselection;

    ----------------------------------------------------------------------------------------------------
    -- ProcessAll() -- PUBLIC
    -- Change status of all License Types and Secondaries to the selected Status
    ----------------------------------------------------------------------------------------------------
    PROCEDURE processall(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        t_outcome               VARCHAR2(400)
                                    := api.pkg_columnquery.VALUE(a_objectid, 'Outcome');
        t_newprocessid          udt_id;
        t_changestatusptid      udt_id
            := api.pkg_configquery.objectdefidforname('p_ChangeStatus');
        t_description           VARCHAR2(4000)
            := api.pkg_columnquery.VALUE(a_objectid, 'Description');
        t_completecancelcount   NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO t_completecancelcount
          FROM api.jobstatuses  js
               JOIN api.statuses st ON st.statusid = js.statusid
         WHERE js.jobtypeid =
               api.pkg_configquery.objectdefidforname('j_LicenseType')
           AND js.statustype IN ('C', 'X')
           AND st.description = t_outcome;

        FOR c
            IN (SELECT lt.jobid ltjobid
                  FROM query.r_licenselicensetype  llt
                       JOIN query.j_licensetype lt
                           ON lt.jobid = llt.licensetypejobid
                 WHERE llt.licensejobid = a_jobid)
        LOOP
            t_newprocessid   :=
                api.pkg_processupdate.new(c.ltjobid,
                                          t_changestatusptid,
                                          t_description,
                                          NULL,
                                          NULL,
                                          NULL);
            api.pkg_processupdate.complete(t_newprocessid, t_outcome);

            -- Set All Batch flags to 'N'
            IF t_completecancelcount > 0 THEN
                pkg_batchtype.setbatchflags(c.ltjobid);
            END IF;
        END LOOP;

        FOR c
            IN (SELECT slt.relationshipid sltrelationshipid
                  FROM query.r_licenselicensetype  llt
                       JOIN query.j_licensetype lt
                           ON lt.jobid = llt.licensetypejobid
                       JOIN query.r_licensetypeltcatsecondary slt
                           ON slt.licensetypejobid = lt.jobid
                 WHERE llt.licensejobid = a_jobid)
        LOOP
            api.pkg_columnupdate.setvalue(c.sltrelationshipid,
                                          'Status',
                                          UPPER(t_outcome));

            -- Set All Batch flags to 'N'
            IF t_completecancelcount > 0 THEN
                pkg_batchtype.setbatchflags(c.sltrelationshipid);
            END IF;
        END LOOP;
    END processall;

    ---------------------------------------------------------
    PROCEDURE flaglicenseforprocessing(a_objectid udt_id, a_asofdate DATE)
    IS
        t_jobid   NUMBER;
        t_relid   NUMBER;
    BEGIN
        IF api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName') =
           'o_HistoricalCorrection' THEN
            BEGIN
                SELECT a.applicationjobid
                  INTO t_jobid
                  FROM query.r_apphistoricalcorrection a
                 WHERE a.historicalcorrectionobjectid = a_objectid
                UNION
                SELECT l.licensejobid
                  FROM query.r_lichistoricalcorrection l
                 WHERE l.historicalcorrectionobjectid = a_objectid;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            UPDATE lessthanzerobalance_t
               SET needsprocessing   = 'Y'
             WHERE jobid = t_jobid;
        ELSE
            UPDATE lessthanzerobalance_t
               SET needsprocessing   = 'Y'
             WHERE jobid = a_objectid;
        END IF;
    END flaglicenseforprocessing;

    ----------------------------------------------------------------------------------------------------
    --  MaintainMasterP12Rels() -- PUBLIC
    --  Create/Remove the Master P12 Relationships on the License JobType
    --  Called from the ThisLicenseIsP12Master detail upon being changed
    ----------------------------------------------------------------------------------------------------
    PROCEDURE maintainmasterp12rels(a_objectid udt_id, a_asofdate DATE)
    IS
        t_licenseisp12master   VARCHAR2(1);
        t_endpointid           udt_id;
        t_newlicobjectid       udt_id;
        t_newrel               udt_id;
    BEGIN
        t_licenseisp12master   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ThisLicenseIsP12Master');
        t_endpointid   :=
            api.pkg_configquery.endpointidforname('j_License', 'P12_One');

        IF t_licenseisp12master = 'Y' THEN
            -- Add the Master P12 Relationship to the License Job
            FOR x
                IN (SELECT ml.jobid
                      FROM query.j_license  l
                           JOIN query.r_licenseprimaryp12legalentity lple
                               ON lple.licensejobid = l.jobid
                           JOIN query.r_licenseprimaryp12legalentity lmple
                               ON lmple.primayrp12leobjectid =
                                  lple.primayrp12leobjectid
                           JOIN query.j_license ml
                               ON ml.jobid = lmple.licensejobid
                     WHERE l.jobid = a_objectid
                       AND ml.thislicenseisp12master = 'Y')
            LOOP
                t_newrel   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   a_objectid,
                                                   x.jobid);
            END LOOP;
        ELSE
            -- Remove the Master P12 Relationship from the License Job
            FOR x IN (SELECT l.relationshipid
                        FROM query.r_p12license l
                       WHERE l.p12license1objectid = a_objectid)
            LOOP
                api.pkg_relationshipupdate.remove(x.relationshipid);
            END LOOP;
        END IF;
    END maintainmasterp12rels;
    
    ------------------------------------------------------------------------------------
  -- 11/15/2021 PK          WO-26526 BIZMod License Validation Code in ABIS - Generate validation Code
  --The function will generate a six-character alphanumeric validation code.
  -------------------------------------------------------------------------------------- 
    
    PROCEDURE generatevalidationcode(a_objectid udt_id, a_asofdate DATE)
    IS
    Begin
            api.pkg_columnupdate.setvalue(
                        a_objectid, 
                        'ValidationCode',
                        DBMS_RANDOM.STRING('X', 6));
            api.pkg_columnupdate.setvalue(
                        a_objectid, 
                        'ValidationCodeCreatedDate',
                        sysdate);
            api.pkg_columnupdate.removevalue(a_objectid,
                                             'RunValidationCodeProcedure');
    
    END generatevalidationcode; 
    ---------------------------------------------------------------------------------------------------------------------------------------
    --  GenerateCreateCatererEventAuthextfilenum() -- PUBLIC
    --  This generates the external file number on the CreatecateretEventAuth process (which is copied to the Issue Caterer auth process).
    
      PROCEDURE generateCreateCatererEventAuthextfilenum(a_objectid udt_id, a_asofdate DATE)
    IS
        t_sequenceid        udt_id;
        t_externalfilenum   VARCHAR2(40);
      --  t_lspid             VARCHAR2(20);
    BEGIN
        SELECT s.sequenceid
          INTO t_sequenceid
          FROM api.sequences s
         WHERE s.description = 'Caterer Sequence';

 --Get the LSPID
     --   t_lspid   := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');
            t_externalfilenum   :=
                api.pkg_utils.generateexternalfilenum('{YYMMDD} -[000]',
                                                      t_sequenceid); --   || '-'
         --   || t_lspid;

         api.pkg_processupdate.setexternalfilenum(a_objectid,
                                                 t_externalfilenum);
        
    END generateCreateCatererEventAuthextfilenum;
    
    ----------------------------------------------------------------------------------------------------
    --  copycreatecaterertoIssuecaterer() -- PUBLIC
    --  Copies external file number on the Create Caterer / Event Authorization process to Issue Caterer / Event Authorization process.
    ----------------------------------------------------------------------------------------------------       
 PROCEDURE copycreatecaterertoIssuecaterer(a_objectid      udt_id,
                                          a_asofdate      DATE,
                                          a_jobid         udt_id)
    IS
        t_IssueCatererprocessid   NUMBER;
        t_externalfilenum         VARCHAR(40);
        t_processtypeid           udt_id;
    BEGIN
        t_processtypeid   :=
            api.pkg_configquery.objectdefidforname('p_IssueCatererEventAuth');
 
            SELECT p2.PROCESSID
             INTO t_IssueCatererprocessid
              FROM (SELECT MAX (p.createddate) Maxcreateddate
                        FROM api.processes p
                        WHERE jobid = a_jobid AND processtypeid IN t_processtypeid) x
                        JOIN api.processes p2 ON p2.CREATEDDATE = x.Maxcreateddate
                        WHERE p2.jobid = a_jobid;

        t_externalfilenum   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ExternalFileNum');

        api.pkg_processupdate.setexternalfilenum(t_IssueCatererprocessid,
                                                 t_externalfilenum);
    END copycreatecaterertoIssuecaterer;

END pkg_license;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_LICENSE TO BIZMOD_API;

GRANT EXECUTE ON SITESPECIFIC.PKG_LICENSE TO POSSEEXTENSIONS;
