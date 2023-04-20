CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_p12a
IS
    -- **************************************************************************
    -- File:
    -- Author:      KEATON
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
    -- 05/15/2012             Created
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    gc_stockholderendpoint   udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'Stockholder');

    gc_officerendpoint       udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Officer');

    gc_p12aparentendpoint    udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'P12AParent');

    gc_p12astockendpoint     udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'P12AStockholder');

    gc_leofficer             udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'OfficerParentEntity');

    gc_lespouse2             udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Spouse2');

    gc_lestockholder         udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'StockholderParentEntity');

    gc_officerdefid          udt_id
        := api.pkg_objectdefquery.idforname('r_OfficerGenPartnerPrincipal');

    gc_stockdefid            udt_id
        := api.pkg_objectdefquery.idforname('r_StockholderLimitedPartner');

    gc_p12adefid             udt_id
        := api.pkg_objectdefquery.idforname('r_P12AStockholderParent');

    t_companyobjid           udt_id;
    t_licobjid               udt_id;
    t_masterleobjid          udt_id;
    t_masterlerelid          udt_id;
    t_masterlicobjid         udt_id;
    t_newrelobjectid         udt_id;
    t_personobjid            udt_id;
    t_processobjid           udt_id;
    t_removerelletolic       udt_id;
    t_runbefore              query.p_convertletop12.relatelehasrunbefore%TYPE;

    --------------------------------------------------------------------------
    -- P12AMasterLELookup
    --------------------------------------------------------------------------
    PROCEDURE p12amasterlelookup(a_object           udt_id,
                                 a_relationshipdef  udt_id,
                                 a_endpoint         udt_endpoint,
                                 a_searchstring     VARCHAR2,
                                 a_relatedobjectids OUT udt_objectlist)
    IS
    BEGIN
        IF a_searchstring IS NULL THEN         /* Being used as a Drop Down */
            a_relatedobjectids   := api.udt_objectlist();

            FOR c_le IN (SELECT r1.toobjectid leobjid
                           FROM api.processes  p
                                JOIN api.relationships r1
                                    ON r1.fromobjectid = p.jobid
                                   AND r1.endpointid IN
                                           (api.pkg_configquery.endpointidforname(
                                                'j_License',
                                                'P12Licensee'),
                                            api.pkg_configquery.endpointidforname(
                                                'j_License',
                                                'LicenseeLegalEntity'))
                          WHERE p.processid = a_object)
            LOOP
                p12arecurmasterlelookup(c_le.leobjid, a_relatedobjectids);
            END LOOP;
        END IF;                                    --if a_SearchString is null
    END p12amasterlelookup;

    ---------------------------------------------------------------------------------------------------
    --  P12A Recursive Canadaite Lookup
    --  This procedure is recursivly called to find all the stockholders on a License
    ---------------------------------------------------------------------------------------------------
    PROCEDURE p12arecurmasterlelookup(
        a_object              udt_id,
        a_relatedobjectids IN OUT udt_objectlist)
    IS
    BEGIN
        FOR c_le
            IN (SELECT r1.toobjectid leobjid, r1.endpointid
                  FROM api.relationships r1
                 WHERE r1.fromobjectid = a_object
                   AND r1.relationshipdefid IN
                           (gc_officerdefid, gc_stockdefid, gc_p12adefid)
                   AND r1.endpointid IN
                           (gc_stockholderendpoint,
                            gc_officerendpoint,
                            gc_p12astockendpoint))
        LOOP
            IF c_le.endpointid = gc_stockholderendpoint THEN
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                    api.udt_object(c_le.leobjid);
            END IF;

            p12arecurmasterlelookup(c_le.leobjid, a_relatedobjectids);
        END LOOP;
    END p12arecurmasterlelookup;

    --------------------------------------------------------------------------
    -- Find P12A Legal Entities select to convert P12A to LE
    --------------------------------------------------------------------------
    PROCEDURE p12alelookup(a_object           udt_id,
                           a_relationshipdef  udt_id,
                           a_endpoint         udt_endpoint,
                           a_searchstring     VARCHAR2,
                           a_relatedobjectids OUT udt_objectlist)
    IS
    BEGIN
        IF a_searchstring IS NULL THEN         /* Being used as a Drop Down */
            a_relatedobjectids   := api.udt_objectlist();

            FOR c_le IN (SELECT r1.toobjectid leobjid
                           FROM api.processes  p
                                JOIN api.relationships r1
                                    ON r1.fromobjectid = p.jobid
                                   AND r1.endpointid IN
                                           (api.pkg_configquery.endpointidforname(
                                                'j_License',
                                                'P12Licensee'),
                                            api.pkg_configquery.endpointidforname(
                                                'j_License',
                                                'LicenseeLegalEntity'))
                          WHERE p.processid = a_object)
            LOOP
                p12areclelookup(c_le.leobjid, a_relatedobjectids);
            END LOOP;
        END IF;                                    --if a_SearchString is null
    END p12alelookup;

    --------------------------------------------------------------------------
    -- Find P12A Legal Entities select to convert P12A to LE
    --------------------------------------------------------------------------
    PROCEDURE p12areclelookup(a_object              udt_id,
                              a_relatedobjectids IN OUT udt_objectlist)
    IS
    BEGIN
        FOR c_le
            IN (SELECT r1.toobjectid leobjid, r1.endpointid
                  FROM api.relationships r1
                 WHERE r1.fromobjectid = a_object
                   AND r1.relationshipdefid IN
                           (gc_officerdefid, gc_stockdefid, gc_p12adefid)
                   AND r1.endpointid IN
                           (gc_stockholderendpoint,
                            gc_officerendpoint,
                            gc_p12astockendpoint))
        LOOP
            IF c_le.endpointid = gc_p12astockendpoint THEN
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                    api.udt_object(c_le.leobjid);
            END IF;

            p12areclelookup(c_le.leobjid, a_relatedobjectids);
        END LOOP;
    END p12areclelookup;

    --------------------------------------------------------------------------
    -- Find P12A Legal Entities to change the P12A master license number
    --------------------------------------------------------------------------

    PROCEDURE p12amasterchangelookup(a_object           udt_id,
                                     a_relationshipdef  udt_id,
                                     a_endpoint         udt_endpoint,
                                     a_searchstring     VARCHAR2,
                                     a_relatedobjectids OUT udt_objectlist)
    IS
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c_le
            IN (SELECT t.leobjectid
                  FROM query.r_masterp12alechangep12amaster  mpc
                       JOIN sitespecific.p12alog_t t
                           ON t.masterleobjectid = mpc.legalentityobjectid
                       JOIN query.o_legalentity le
                           ON t.leobjectid = le.objectid
                 WHERE mpc.changep12amasterprocessid = a_object
                   AND t.leobjectid != t.masterleobjectid
                   AND le.licensejobid IS NOT NULL)
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c_le.leobjectid);
        END LOOP;
    END p12amasterchangelookup;

    ---------------------------------------------------------------------------------------------------
    --   * RelateLEtoProcessForP12() -- PUBLIC
    -- Referencing the Master Legal Entity, find all other LEs for that same Company or Person
    -- which are Stockholders, and relate them to process p_convertLEtoP12
    -- as part of converting the Legal Enties to P12.
    ---------------------------------------------------------------------------------------------------
    PROCEDURE relateletoprocessforp12a(a_relationshipid udt_id,
                                       a_asofdate      DATE)
    IS
        t_masterlegalentityendpoint    NUMBER
            := api.pkg_configquery.endpointidforname('p_ConvertLEToP12A',
                                                     'MasterLegalEntity');
        t_leconvertingtop12aendpoint   NUMBER
            := api.pkg_configquery.endpointidforname('p_ConvertLEToP12A',
                                                     'LEConvertingToP12A');
        t_companyepid                  NUMBER
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Company');
        t_personepid                   NUMBER
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Person');
        t_licensedefid                 NUMBER
            := api.pkg_configquery.objectdefidforname('j_License');
        t_applicationdefid             NUMBER
            := api.pkg_configquery.objectdefidforname('j_Application');
        t_relatedobjects               udt_objectlist;
        t_p12aid                       NUMBER;
    BEGIN
        SELECT mle.legalentityobjectid,
               mle.convertletop12aprocessid,
               cp.relatelehasrunbefore
          INTO t_masterleobjid, t_processobjid, t_runbefore
          FROM query.r_convertletop12amasterle  mle
               JOIN query.p_convertletop12a cp
                   ON cp.processid = mle.convertletop12aprocessid
         WHERE mle.relationshipid = a_relationshipid;

        IF t_runbefore = 'Y' THEN -- Remove rels established by previous run of this procedure.
            FOR c_exist IN (SELECT relationshipid
                              FROM api.relationships
                             WHERE fromobjectid = t_processobjid
                               AND endpointid = t_leconvertingtop12aendpoint)
            LOOP
                -- remove relationship Process to LE Candidate
                api.pkg_relationshipupdate.remove(c_exist.relationshipid);
            END LOOP;   -- rels established by previous run of this procedure.
        END IF;                                                 -- t_runbefore

        BEGIN
            SELECT toobjectid
              INTO t_companyobjid
              FROM api.relationships
             WHERE fromobjectid = t_masterleobjid
               AND endpointid = t_companyepid;

            -- Find all the Legal Entities associated with this Company which are Owners
            -- and the License is not canceled.
            FOR c_lec
                IN (SELECT slp.stockholderobjectid
                      FROM query.r_legalentitycompany  lec
                           JOIN query.r_legalentitycompany lec2
                               ON lec2.companyobjectid = lec.companyobjectid
                           JOIN query.r_stockholderlimitedpartner slp
                               ON slp.stockholderobjectid =
                                  lec2.legalentityobjectid
                           JOIN query.j_license l
                               ON l.objectid =
                                  sitespecific.pkg_legalentity.getlicorappforle(
                                      slp.stockholderobjectid)
                     WHERE lec.legalentityobjectid = t_masterleobjid
                       AND slp.stockholderobjectid != t_masterleobjid
                       AND lec.companyobjectid = t_companyobjid
                       AND l.statusid IN
                               (SELECT js.statusid
                                  FROM api.jobstatuses js
                                 WHERE js.jobtypeid = t_licensedefid
                                   AND js.statustype != 'X'
                                   AND js.statustype != 'C')
                    UNION
                    SELECT slp.stockholderobjectid
                      FROM query.r_legalentitycompany  lec
                           JOIN query.r_legalentitycompany lec2
                               ON lec2.companyobjectid = lec.companyobjectid
                           JOIN query.r_stockholderlimitedpartner slp
                               ON slp.stockholderobjectid =
                                  lec2.legalentityobjectid
                           JOIN query.j_application a
                               ON a.objectid =
                                  sitespecific.pkg_legalentity.getlicorappforle(
                                      slp.stockholderobjectid)
                     WHERE lec.legalentityobjectid = t_masterleobjid
                       AND slp.stockholderobjectid != t_masterleobjid
                       AND lec.companyobjectid = t_companyobjid
                       AND a.statusid IN
                               (SELECT js.statusid
                                  FROM api.jobstatuses js
                                 WHERE js.jobtypeid = t_applicationdefid
                                   AND js.statustype != 'X'
                                   AND js.statustype != 'C'))
            LOOP
                -- relate Licensee Company Legal Entity as P12 Candidate
                t_p12aid   :=
                    api.pkg_columnquery.numericvalue(
                        c_lec.stockholderobjectid,
                        'P12AMasterLEIdLookup');

                IF t_p12aid IS NOT NULL THEN -- If the P12A canadite is nested set do not maintain to Y
                    api.pkg_columnupdate.setvalue(t_p12aid,
                                                  'DoNotMaintain',
                                                  'Y');
                    api.pkg_columnupdate.setvalue(c_lec.stockholderobjectid,
                                                  'DoNotMaintain',
                                                  'Y');
                END IF;

                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        t_leconvertingtop12aendpoint,
                        t_processobjid,
                        c_lec.stockholderobjectid);
            END LOOP; -- Company Legal Entities on New or Pending Applications
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                SELECT toobjectid
                  INTO t_personobjid
                  FROM api.relationships
                 WHERE fromobjectid = t_masterleobjid
                   AND endpointid = t_personepid;

                FOR c_lep
                    IN (SELECT slp.stockholderobjectid
                          FROM query.r_legalentityperson  lep
                               JOIN query.o_person p
                                   ON p.objectid = lep.personobjectid
                               JOIN query.r_legalentityperson lep2
                                   ON lep2.personobjectid =
                                      lep.personobjectid
                               JOIN query.r_stockholderlimitedpartner slp
                                   ON slp.stockholderobjectid =
                                      lep2.legalentityobjectid
                               JOIN query.j_license l
                                   ON l.objectid =
                                      sitespecific.pkg_legalentity.getlicorappforle(
                                          slp.stockholderobjectid)
                         WHERE lep.legalentityobjectid = t_masterleobjid
                           AND slp.stockholderobjectid != t_masterleobjid
                           AND lep.personobjectid = t_personobjid
                           AND l.statusid IN
                                   (SELECT js.statusid
                                      FROM api.jobstatuses js
                                     WHERE js.jobtypeid = t_licensedefid
                                       AND js.statustype != 'X'
                                       AND js.statustype != 'C')
                        UNION
                        SELECT slp.stockholderobjectid
                          FROM query.r_legalentityperson  lep
                               JOIN query.o_person p
                                   ON p.objectid = lep.personobjectid
                               JOIN query.r_legalentityperson lep2
                                   ON lep2.personobjectid =
                                      lep.personobjectid
                               JOIN query.r_stockholderlimitedpartner slp
                                   ON slp.stockholderobjectid =
                                      lep2.legalentityobjectid
                               JOIN query.j_application a
                                   ON a.objectid =
                                      sitespecific.pkg_legalentity.getlicorappforle(
                                          slp.stockholderobjectid)
                         WHERE lep.legalentityobjectid = t_masterleobjid
                           AND slp.stockholderobjectid != t_masterleobjid
                           AND lep.personobjectid = t_personobjid
                           AND a.statusid IN
                                   (SELECT js.statusid
                                      FROM api.jobstatuses js
                                     WHERE js.jobtypeid = t_applicationdefid
                                       AND js.statustype != 'X'
                                       AND js.statustype != 'C'))
                LOOP
                    -- relate Licensee Company Legal Entity as P12 Candidate
                    t_p12aid   :=
                        api.pkg_columnquery.numericvalue(
                            c_lep.stockholderobjectid,
                            'P12AMasterLEIdLookup');

                    IF t_p12aid IS NOT NULL THEN -- If the P12A canadite is nested set do not maintain to Y
                        api.pkg_columnupdate.setvalue(t_p12aid,
                                                      'DoNotMaintain',
                                                      'Y');
                        api.pkg_columnupdate.setvalue(
                            c_lep.stockholderobjectid,
                            'DoNotMaintain',
                            'Y');
                    END IF;

                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            t_leconvertingtop12aendpoint,
                            t_processobjid,
                            c_lep.stockholderobjectid);
                END LOOP;         -- Person Legal Entities for Application Job
        END;

        -- Set Flag to show Procedure has been ran.
        api.pkg_columnupdate.setvalue(t_processobjid,
                                      'RelateLEHasRunBefore',
                                      'Y');
    END relateletoprocessforp12a;

    ---------------------------------------------------------------------------------------------------
    --   * ConvertLEToP12A() -- PUBLIC
    -- Called at completion of process p_convertLEtoP12A.
    -- Sets P12A status on P12A Master Legal Entity.
    -- Sets P12A Master license jobid on P12A Master Legal Entity.
    -- For Each Legal Entity candidate related to process, removes existing LE StockholderRel and relates
    -- to Master P12A Legal Entity as a P12A relationship
    ---------------------------------------------------------------------------------------------------
    PROCEDURE convertletop12a(a_processobjectid udt_id, a_asofdate DATE)
    IS
        t_countd                   NUMBER := 1;
        t_countc                   NUMBER := 1;

        t_mlecheckid               NUMBER;
        t_parentlegalentityobjid   NUMBER;
        t_rellicobjid              udt_objectlist;
        t_fromobjectid             NUMBER;
        t_lestodelete              udt_objectlist;
        t_lestocopy                udt_objectlist;
        t_p12aparentendpt          NUMBER
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'P12AParent');
    BEGIN
        -- Verify that there is a Master Legal Entity Related to the ConvertLEToP12A process (cardinality is not used
        -- because that legal entity is delected when the Person/Company related to the Master Legal Entity is
        -- already a P12A on another License.
        SELECT COUNT(mle.relationshipid)
          INTO t_mlecheckid
          FROM query.r_convertletop12amasterle mle
         WHERE mle.convertletop12aprocessid = a_processobjectid;

        IF t_mlecheckid = 0 THEN
            api.pkg_errors.raiseerror(
                -20000,
                'This process must have a P12A Master LE selected before completion.');
        END IF;

        --When there is no pre-existing P12A Master Legal Entity, substitute into t_MasterLEObjId the le.objectid of the
        --Legal Entity selected by the user in the Master Legal Entity Relationship and set the License and Legal Entity as the Masters.
        -- begin
        SELECT r.toobjectid, r.relationshipid
          INTO t_masterleobjid, t_masterlerelid
          FROM api.relationships r
         WHERE r.fromobjectid = a_processobjectid
           AND r.endpointid =
               api.pkg_configquery.endpointidforname('p_ConvertLEToP12A',
                                                     'MasterLegalEntity');

        -- Identify the Master License
        SELECT p.jobid
          INTO t_masterlicobjid
          FROM api.processes p
         WHERE p.processid = a_processobjectid;

        INSERT INTO p12alog_t
             VALUES (t_masterleobjid, t_masterleobjid);

        -- Set P12A Master indicator on Legal Entity
        api.pkg_columnupdate.setvalue(t_masterleobjid,
                                      'P12AMasterLicenseJobId',
                                      t_masterlicobjid);

        -- Set P12A Master indicator on Legal Entity
        api.pkg_columnupdate.setvalue(t_masterleobjid, 'P12AStatus', 'Y');

        -- Set P12A Master Le Id
        api.pkg_columnupdate.setvalue(t_masterleobjid,
                                      'P12AMasterLEId',
                                      t_masterleobjid);
        --Set Do Not Maintain to N

        api.pkg_columnupdate.setvalue(t_masterleobjid, 'DoNotMaintain', 'N');

        -- Set up Master P12A Legal Entity Relationship
        SELECT r.relationshipid, r.parententityobjectid
          INTO t_removerelletolic, t_parentlegalentityobjid
          FROM query.r_stockholderlimitedpartner r
         WHERE r.stockholderobjectid = t_masterleobjid;

        -- Remove Stockholder relationship to Master License.
        api.pkg_relationshipupdate.remove(t_removerelletolic);

        -- Relate the Master P12A Legal Entity to the P12A Master License.
        t_newrelobjectid   :=
            api.pkg_relationshipupdate.new(t_p12aparentendpt,
                                           t_masterleobjid,
                                           t_parentlegalentityobjid);

        -- Find LE object ids that are related to the ConvertLEToP12A process, loop through and convert to P12As
        FOR c_1
            IN (SELECT r.toobjectid
                           leobjid,
                       r.relationshipid,
                       api.pkg_columnquery.numericvalue(r.toobjectid,
                                                        'ParentObjectId')
                           parentobjectid
                  FROM api.relationships r
                 WHERE fromobjectid = a_processobjectid       --t_ProcessObjId
                   AND endpointid =
                       api.pkg_configquery.endpointidforname(
                           'p_ConvertLEToP12A',
                           'LEConvertingToP12A'))
        LOOP
            -- Find license to which this LE is related
            t_licobjid      :=
                sitespecific.pkg_legalentity.getlicorappforle(c_1.leobjid);

            INSERT INTO p12alog_t
                 VALUES (c_1.leobjid, t_masterleobjid);


            SELECT r.relationshipid, r.parententityobjectid
              INTO t_removerelletolic, t_parentlegalentityobjid
              FROM query.r_stockholderlimitedpartner r
             WHERE r.stockholderobjectid = c_1.leobjid;

            IF t_parentlegalentityobjid = c_1.parentobjectid THEN
                --Create a new P12A rel and Remove the old LE stockholder rel
                api.pkg_relationshipupdate.remove(t_removerelletolic);

                -- Relate the LE as a P12A LE
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_p12aparentendpt,
                                                   c_1.leobjid,
                                                   c_1.parentobjectid);
            ELSE
                --If these don't match we have a data issue that we have encountered
                api.pkg_errors.raiseerror(
                    -20000,
                    'Error creating P12A relationships');
            END IF;

            --Set the P12A Status and the Master JobId
            api.pkg_columnupdate.setvalue(c_1.leobjid, 'P12AStatus', 'Y');

            api.pkg_columnupdate.setvalue(c_1.leobjid,
                                          'P12AMasterLicenseJobId',
                                          t_masterlicobjid);

            api.pkg_columnupdate.setvalue(c_1.leobjid,
                                          'P12AMasterLEId',
                                          t_masterleobjid);

            api.pkg_columnupdate.setvalue(c_1.leobjid, 'DoNotMaintain', 'N');

            t_lestodelete   := api.udt_objectlist();
            sitespecific.pkg_legalentity.getlegalentitychildren(
                c_1.leobjid,
                t_lestodelete);

            FOR d IN 1 .. t_lestodelete.COUNT
            LOOP
                api.pkg_objectupdate.remove(t_lestodelete(d).objectid);
            END LOOP;

            FOR c_3 IN (SELECT r.relationshipid, r.endpointid, r.toobjectid
                          FROM api.relationships r
                         WHERE r.endpointid IN (gc_p12astockendpoint,
                                                gc_officerendpoint,
                                                gc_lespouse2,
                                                gc_stockholderendpoint)
                           AND r.fromobjectid = t_masterleobjid)
            LOOP
                pkg_legalentity.p12acopy(c_3.relationshipid,
                                         t_masterleobjid,
                                         c_1.leobjid,
                                         c_3.endpointid);
            END LOOP;
        END LOOP;                                                 --End of c_1
    END convertletop12a;

    ---------------------------------------------------------------------------------------------------
    --   * ConvertLEToP12() -- PUBLIC
    -- Called at completion of process p_convertP12toLE.
    -- Sets P12 status on P12 Master Legal Entity.
    -- Sets P12 Master status on P12 Master License.
    -- For Each Legal Entity candidate related to process, removes existing LE Licensee and relates
    -- to Master P12 Legal Entity
    ---------------------------------------------------------------------------------------------------
    PROCEDURE convertp12atole(a_processobjectid udt_id, a_asofdate DATE)
    IS
        t_p12amasterjobid       udt_id;
        t_raiseerror            BOOLEAN := FALSE;
        t_parentobjectid        udt_id;
        t_stockholderobjectid   udt_id;
        t_relationshipid        udt_id;
        t_newrelationshipid     udt_id;
        t_p12atoleobjid         udt_id;
    BEGIN
        -- Verify that there is a Master Legal Entity Related to the ConvertLEToP12 process (cardinality is not used
        -- because that legal entity is delected when the Person/Company related to the Master Legal Entity is
        -- already a P12 on another License.


        -- Identify the Master Legal Entity, as defined by the Convert P12 Process

        --Person: Select P12 Master LE Object Id and License Job into MasterLEObjId and MasterLicObjId from pre-existing
        --Master Legal Entity

        BEGIN
            /*select cle.LegalEntityObjectId, api.pkg_columnquery.NumericValue(cle.LegalEntityObjectId, 'P12AMasterLicenseJobId')
              into t_MasterLEObjId, t_P12AMasterJobId
              from query.r_ConvertP12AtoLEMasterP12ALE cle
             where cle.ConvertP12AtoLEObjectId = a_ProcessObjectId;*/

            SELECT t.masterleobjectid,
                   cle.legalentityobjectid,
                   api.pkg_columnquery.numericvalue(t.masterleobjectid,
                                                    'P12AMasterLicenseJobId')
              INTO t_masterleobjid, t_p12atoleobjid, t_p12amasterjobid
              FROM query.r_convertp12atolemasterp12ale  cle
                   JOIN p12alog_t t ON t.leobjectid = cle.legalentityobjectid
             WHERE cle.convertp12atoleobjectid = a_processobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_raiseerror   := TRUE;
        END;

        IF t_raiseerror THEN
            api.pkg_errors.raiseerror(
                -20000,
                'This process must have a P12A LE selected before completion.');
        END IF;


        IF api.pkg_columnquery.VALUE(a_processobjectid,
                                     'ConvertAllToLegalEntities') =
           'N' THEN
            IF t_p12amasterjobid =
               api.pkg_columnquery.VALUE(a_processobjectid, 'JobId') THEN
                api.pkg_errors.raiseerror(
                    -20001,
                    'You must convert all P12As to a legal entitys, when running this process on the master license');
            END IF;

            -- Identify the Current License
            SELECT p.jobid
              INTO t_masterlicobjid
              FROM api.processes p
             WHERE p.processid = a_processobjectid;

            -- Set up Legal Entity Relationship
            DELETE FROM p12alog_t p12
                  WHERE p12.leobjectid = t_p12atoleobjid;

            SELECT shp.p12aparentobjectid,
                   shp.p12astockholderobjectid,
                   shp.relationshipid
              INTO t_parentobjectid, t_stockholderobjectid, t_relationshipid
              FROM query.r_p12astockholderparent shp
             WHERE shp.p12astockholderobjectid = t_p12atoleobjid;

            api.pkg_relationshipupdate.remove(t_relationshipid);


            t_newrelationshipid   :=
                api.pkg_relationshipupdate.new(gc_stockholderendpoint,
                                               t_parentobjectid,
                                               t_stockholderobjectid);


            api.pkg_columnupdate.removevalue(t_p12atoleobjid,
                                             'P12AMasterLicenseJobId');
            api.pkg_columnupdate.removevalue(t_p12atoleobjid,
                                             'P12AMasterLEId');
            api.pkg_columnupdate.setvalue(t_p12atoleobjid, 'P12AStatus', 'N');
        ELSE
            FOR e
                IN (SELECT UNIQUE p122.leobjectid, p122.masterleobjectid
                      FROM p12alog_t  p12
                           JOIN p12alog_t p122
                               ON p12.masterleobjectid =
                                  p122.masterleobjectid
                           JOIN query.o_legalentity le
                               ON le.objectid = p122.leobjectid
                     WHERE p12.leobjectid = t_p12atoleobjid)
            LOOP
                api.pkg_columnupdate.removevalue(e.leobjectid,
                                                 'P12AMasterLicenseJobId');
                api.pkg_columnupdate.removevalue(e.leobjectid,
                                                 'P12AMasterLEId');
                api.pkg_columnupdate.setvalue(e.leobjectid,
                                              'P12AStatus',
                                              'N');

                SELECT shp.p12aparentobjectid,
                       shp.p12astockholderobjectid,
                       shp.relationshipid
                  INTO t_parentobjectid,
                       t_stockholderobjectid,
                       t_relationshipid
                  FROM query.r_p12astockholderparent shp
                 WHERE shp.p12astockholderobjectid = e.leobjectid;

                api.pkg_relationshipupdate.remove(t_relationshipid);


                t_newrelationshipid   :=
                    api.pkg_relationshipupdate.new(gc_stockholderendpoint,
                                                   t_parentobjectid,
                                                   t_stockholderobjectid);
            END LOOP;

            api.pkg_columnupdate.removevalue(t_masterleobjid,
                                             'P12AMasterLicenseJobId');
            api.pkg_columnupdate.removevalue(t_masterleobjid,
                                             'P12AMasterLEId');
            api.pkg_columnupdate.setvalue(t_masterleobjid, 'P12AStatus', 'N');

            -- Set up Legal Entity Relationship
            DELETE FROM p12alog_t p12
                  WHERE p12.masterleobjectid = t_masterleobjid;
        END IF;
    END convertp12atole;

    PROCEDURE p12adeletecleanup(a_objectid udt_id, a_asofdate DATE)
    IS
        t_cleanupid   udt_id;
    BEGIN
        DELETE FROM p12alog_t t
              WHERE t.leobjectid = a_objectid;
    END p12adeletecleanup;

    /* Procedure P12ADeleteCleanUp(a_RelationshipId      udt_Id,
                                 a_AsOfDate            Date)is

     t_CleanUpId udt_id;

     begin

      select sp.P12AStockholderObjectId
        into t_CleanUpId
        from query.r_P12astockholderparent sp
       where sp.RelationshipId = a_RelationshipId;

      --api.pkg_columnupdate.SetValue(t_CleanUpId, 'DoNotMaintain', 'Y');

      delete from P12ALOG_T t
      where t.leobjectid = t_CleanUpId;

     end P12ADeleteCleanUp;*/

    ---------------------------------------------------------------------------------------------------
    --   * MaintainP12A() -- PUBLIC
    -- Called at change of Master P12A to maintain all P12A children
    ---------------------------------------------------------------------------------------------------
    PROCEDURE maintainp12a(a_objectid udt_id, a_asofdate DATE)
    IS
        t_lestodelete   udt_objectlist;
    BEGIN
        SELECT le.p12amasterleidlookup
          INTO t_masterleobjid
          FROM query.o_legalentity le
         WHERE le.objectid = a_objectid;

        IF api.pkg_columnquery.VALUE(t_masterleobjid, 'DoNotMaintain') = 'Y' THEN
            api.pkg_columnupdate.setvalue(t_masterleobjid,
                                          'DoNotMaintain',
                                          'N');
        ELSE
            -- Find LE object ids that are related to Master LE object and maintain them
            FOR c_1
                IN (SELECT  /*+ cardinality (x,10) */
                           le.objectid leobjid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_LegalEntity',
                                       'P12AMasterLEId',
                                       t_masterleobjid) AS api.udt_objectlist))
                           x
                           JOIN query.o_legalentity le
                               ON le.objectid = x.objectid
                     WHERE le.objectid != t_masterleobjid
                       AND le.p12astatus = 'Y')
            LOOP
                t_lestodelete   := api.udt_objectlist();
                sitespecific.pkg_legalentity.getlegalentitychildren(
                    c_1.leobjid,
                    t_lestodelete);

                FOR d IN 1 .. t_lestodelete.COUNT
                LOOP
                    IF api.pkg_columnquery.VALUE(t_lestodelete(d).objectid,
                                                 'P12AStatus') =
                       'Y' THEN
                        DELETE FROM p12alog_t t
                              WHERE t.leobjectid = t_lestodelete(d).objectid;
                    END IF;

                    api.pkg_objectupdate.remove(t_lestodelete(d).objectid);
                END LOOP;

                FOR c_3
                    IN (SELECT r.relationshipid, r.endpointid, r.toobjectid
                          FROM api.relationships r
                         WHERE r.endpointid IN (gc_p12astockendpoint,
                                                gc_officerendpoint,
                                                gc_lespouse2,
                                                gc_stockholderendpoint)
                           AND r.fromobjectid = t_masterleobjid)
                LOOP
                    pkg_legalentity.p12acopy(c_3.relationshipid,
                                             t_masterleobjid,
                                             c_1.leobjid,
                                             c_3.endpointid,
                                             FALSE,
                                             TRUE);
                END LOOP;
            END LOOP;
        END IF;
    END maintainp12a;

    /*----------------------------------------------------------
     * ChangeP12AMasterLicense()
     * This procedure is run on the outcome of the Change P12A master license process
     * It updates the P12Alog_t table to chnage the P12A Master LE,
     * Also it updates the P12A Master License JobId on the P12A LEs
     *---------------------------------------------------------*/

    PROCEDURE changep12amasterlicense(a_objectid udt_id, a_asofdate DATE)
    IS
        t_newmasterleobjid        udt_id;
        t_newmasterlicenseid      udt_id;
        t_oldmasterlicensejobid   udt_id;
    BEGIN
        SELECT pnm.legalentityobjectid,
               api.pkg_columnquery.VALUE(pnm.legalentityobjectid,
                                         'LicenseJobId'),
               api.pkg_columnquery.VALUE(pnm.legalentityobjectid,
                                         'P12AMasterLicenseJobId')
          INTO t_newmasterleobjid,
               t_newmasterlicenseid,
               t_oldmasterlicensejobid
          FROM query.r_p12alechangep12amaster pnm
         WHERE pnm.changep12amasterprocessid = a_objectid;

        IF api.pkg_columnquery.numericvalue(a_objectid, 'JobId') !=
           t_oldmasterlicensejobid THEN
            api.pkg_errors.raiseerror(
                -20000,
                'You must be on the P12A master license to change the P12A master.');
        END IF;

        FOR c
            IN (SELECT t.leobjectid, t.masterleobjectid
                  FROM query.r_masterp12alechangep12amaster  mpc
                       JOIN sitespecific.p12alog_t t
                           ON t.masterleobjectid = mpc.legalentityobjectid
                       JOIN query.o_legalentity le
                           ON le.objectid = t.leobjectid
                 WHERE mpc.changep12amasterprocessid = a_objectid)
        LOOP
            UPDATE p12alog_t t
               SET t.masterleobjectid   = t_newmasterleobjid
             WHERE t.leobjectid = c.leobjectid
               AND t.masterleobjectid = c.masterleobjectid;

            api.pkg_columnupdate.setvalue(c.leobjectid,
                                          'P12AMasterLEId',
                                          t_newmasterleobjid);
            api.pkg_columnupdate.setvalue(c.leobjectid,
                                          'P12AMasterLicenseJobId',
                                          t_newmasterlicenseid);
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            api.pkg_errors.raiseerror(
                -20000,
                'You must select a new master license number before completing this process.');
    END changep12amasterlicense;
    
    
  /*----------------------------------------------------------
  * UpdateP12AMasterLicense()
  * Called from the p12 conversion procedures
  * 
  * When the p12a master legal entity is replaced on the license:
  * 1. Update the p12aLog records
  * 2. Update the p12aMasterLEId on all related p12a Hierarchies
  *---------------------------------------------------------*/
  Procedure UpdateP12AMasterLE (a_p12aMasterLEId  udt_id,
                                a_AsOfDate   date) is
    t_p12aMaster         varchar2(1);                                     
    t_p12aHierarchies    api.pkg_definition.udt_IdList; 
    t_MasterLEObjectIds  api.pkg_definition.udt_IdList; 
    t_LEObjectDefId      number := api.pkg_ConfigQuery.ObjectDefIdForName('o_LegalEntity');  
    t_LicenseDefId       number := api.pkg_ConfigQuery.ObjectDefIdForName('j_License');  
    t_LegalEntities      api.udt_ObjectList;
    t_NewP12AMaster      api.pkg_definition.udt_id;
    t_Count              number;
        
  begin

    --if a p12a has not been passed in then do not perform any of the processing below
    if a_p12aMasterLEId is null then
      return;
    end if;
    
    select /*+ cardinality (x,10) */
            count(le.objectid)
      into t_count
      from table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_LegalEntity','P12AMasterLEId', a_p12aMasterLEId) as api.udt_ObjectList)) x
      join query.o_legalentity le on le.objectid = x.objectid
     where le.ObjectId != a_p12aMasterLEId
       and le.P12AStatus = 'Y';  
    
    --if the p12a hierarchy returns no records then do not perform any of the processing below 
    if t_Count = 0 then
      return;
    end if;  
        
    --get all p12a legal entity hierarchies for the old p12a master legal entity
    select /*+ cardinality (x,10) */
            le.objectid LeObjId
     bulk collect into t_p12aHierarchies
      from table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_LegalEntity','P12AMasterLEId', a_p12aMasterLEId) as api.udt_ObjectList)) x
      join query.o_legalentity le on le.objectid = x.objectid
     where le.P12AStatus = 'Y';
      
    --find the child p12a hierarchy that is now the p12a master legal entity
    for x in ( select le.Column_Value
                 from table( t_p12aHierarchies ) le   ) loop 
      if api.pkg_ColumnQuery.Value( x.Column_Value , 'P12AMasterLicenseJobId') = api.pkg_ColumnQuery.Value( x.Column_Value , 'LicenseJobId') then
         t_NewP12AMaster := x.Column_Value;
         exit;
      end if;
    end loop;  
       
    --clean up all child p12a hierarchies when a new p12a master exists.
    --confirm that the new master differs from the old master
    if t_NewP12AMaster > 0 and ( t_NewP12AMaster <> a_p12aMasterLEId ) then
      --remove old p12aLog records
      delete from sitespecific.p12alog_t
       where masterleobjectid = a_p12aMasterLEId;         
    
      for x in ( select le.Column_Value
                   from table( t_p12aHierarchies ) le   ) loop  
                          
        --add new p12aLog records           
        insert into sitespecific.p12alog_t 
            values ( x.Column_Value , t_NewP12AMaster );  
            
        --update p12a hierarchies to use the new p12a Master LE     
        api.pkg_columnupdate.SetValue( x.Column_Value, 'DoNotMaintain', 'Y');  
        api.pkg_columnupdate.SetValue( x.Column_Value, 'P12AMasterLEId', t_NewP12AMaster);

      end loop;
      
      --remove previous p12a master legal entities 
      t_LegalEntities := api.udt_objectlist();
      sitespecific.pkg_Legalentity.GetLegalEntityChildren(a_p12aMasterLEId, t_LegalEntities);
      for i in 1..t_LegalEntities.Count loop
        api.pkg_columnupdate.SetValue( t_LegalEntities(i).ObjectId , 'DoNotMaintain', 'Y'); 
        api.pkg_Objectupdate.Remove( t_LegalEntities(i).ObjectId );
      end loop;

      --remove the old p12a master
      api.pkg_columnupdate.SetValue( a_p12aMasterLEId , 'DoNotMaintain', 'Y'); 
      api.pkg_Objectupdate.Remove( a_p12aMasterLEId ); 
      
    end if;

  end UpdateP12AMasterLE;
      
END pkg_p12a;

/
