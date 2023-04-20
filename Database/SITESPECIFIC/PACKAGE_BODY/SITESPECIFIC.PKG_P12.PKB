CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_p12
IS
    -- **************************************************************************
    -- File:        PKG_P12.PKB
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
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    t_companyobjid          udt_id;
    t_licobjid              udt_id;
    t_masterleobjid         udt_id;
    t_masterlicobjid        udt_id;
    t_newrelobjectid        udt_id;
    t_personobjid           udt_id;
    t_processobjid          udt_id;
    t_removerelletolic      udt_id;
    t_runbefore             query.p_convertletop12.relatelehasrunbefore%TYPE;

    gc_p12selfep   CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('j_License', 'P12_One') ;

    --------------------------------------------------------------------------
    -- FindUsersForP12MasterLELookup
    --------------------------------------------------------------------------
    PROCEDURE p12masterlelookup(a_object           udt_id,
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
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                    api.udt_object(c_le.leobjid);
            END LOOP;
        END IF;                                    --if a_SearchString is null
    END p12masterlelookup;

    ---------------------------------------------------------------------------------------------------
    --   * RelateLEtoProcessForP12() -- PUBLIC
    -- Referencing the Master Legal Entity, find all other LEs for that same Company or Person
    -- which are Licensees, and relate them to process p_convertLEtoP12
    -- as part of converting the Legal Enties to P12.
    ---------------------------------------------------------------------------------------------------
    PROCEDURE relateletoprocessforp12(a_relationshipid udt_id,
                                      a_asofdate      DATE)
    IS
        t_masterleep         udt_id
            := api.pkg_configquery.endpointidforname('p_ConvertLEToP12',
                                                     'MasterLegalEntity');
        t_convertleep        udt_id
            := api.pkg_configquery.endpointidforname('p_ConvertLEToP12',
                                                     'LEConvertingToP12');
        t_companyep          udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Company');
        t_lelicenseeep       udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'LegalEntityLicense');
        t_leapplicationep    udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'AppApplication');
        t_lepersonep         udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Person');
        t_licensedefid       udt_id
            := api.pkg_configquery.objectdefidforname('j_License');
        t_applicationdefid   udt_id
            := api.pkg_configquery.objectdefidforname('j_Application');
        t_jobid              udt_id;
    BEGIN
        SELECT r.toobjectid,
               r.fromobjectid,
               p.relatelehasrunbefore,
               p.jobid
          INTO t_masterleobjid,
               t_processobjid,
               t_runbefore,
               t_jobid
          FROM api.relationships  r
               JOIN query.p_convertletop12 p ON p.objectid = r.fromobjectid
         WHERE r.relationshipid = a_relationshipid
           AND r.endpointid = t_masterleep;

        IF t_runbefore = 'Y' THEN -- Remove rels established by previous run of this procedure.
            FOR c_exist IN (SELECT relationshipid
                              FROM api.relationships
                             WHERE fromobjectid = t_processobjid
                               AND endpointid = t_convertleep)
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
               AND endpointid = t_companyep;

            -- Find all the Legal Entities associated with this Company which are Licensees
            -- and the License is not canceled. TODO which statusnames should be included?
            FOR c_lec IN (SELECT r1.fromobjectid leobjid, lic.jobid
                            FROM api.relationships  r1
                                 JOIN api.relationships r2
                                     ON (r2.fromobjectid = r1.fromobjectid
                                     AND r2.endpointid = t_lelicenseeep)
                                 JOIN query.j_license lic
                                     ON (lic.objectid = r2.toobjectid
                                     AND lic.statusid IN
                                             (SELECT js.statusid
                                                FROM api.jobstatuses js
                                               WHERE js.jobtypeid =
                                                     t_licensedefid
                                                 AND js.statustype != 'X'
                                                 AND js.statustype != 'C'))
                           WHERE r1.toobjectid = t_companyobjid
                             AND r2.fromobjectid <> t_masterleobjid -- TODO 05.060.2008 TEST THIS
                             AND r1.endpointid = t_companyep
                             AND lic.objectid <> t_jobid)
            LOOP
                -- relate Licensee Company Legal Entity as P12 Candidate
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_convertleep,
                                                   t_processobjid,
                                                   c_lec.leobjid);
            END LOOP; -- Company Legal Entities on Licenses (of appropriate status)


            FOR c_lec IN (SELECT r1.fromobjectid leobjid, app.jobid
                            FROM api.relationships  r1
                                 JOIN api.relationships r2
                                     ON (r2.fromobjectid = r1.fromobjectid
                                     AND r2.endpointid = t_leapplicationep)
                                 JOIN query.j_application app
                                     ON (app.objectid = r2.toobjectid
                                     AND app.statusid IN
                                             (SELECT js.statusid
                                                FROM api.jobstatuses  js
                                                     JOIN api.statuses s
                                                         ON s.statusid =
                                                            js.statusid
                                               WHERE js.jobtypeid =
                                                     t_applicationdefid --app.jobtypeid
                                                 AND s.tag IN ('NEW',
                                                               'PEND',
                                                               'APPLD',
                                                               'DENIED')))
                           WHERE r1.toobjectid = t_companyobjid
                             AND r2.fromobjectid <> t_masterleobjid -- TODO 05.060.2008 TEST THIS
                             AND r1.endpointid = t_companyep)
            LOOP
                -- relate Applicant Company Legal Entity as P12 Candidate
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(t_convertleep,
                                                   t_processobjid,
                                                   c_lec.leobjid);
            END LOOP; -- Company Legal Entities on New or Pending Applications
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                SELECT toobjectid
                  INTO t_personobjid
                  FROM api.relationships
                 WHERE fromobjectid = t_masterleobjid
                   AND endpointid = t_lepersonep;

                FOR c_lep IN (SELECT -- Find all the Legal Entities associated with this Person which are Licensees
                                     r1.fromobjectid leobjid, lic.jobid
                                FROM api.relationships  r1
                                     JOIN api.relationships r2
                                         ON (r2.fromobjectid =
                                             r1.fromobjectid
                                         AND r2.endpointid = t_lelicenseeep)
                                     JOIN query.j_license lic
                                         ON (lic.objectid = r2.toobjectid
                                         AND lic.statusid IN
                                                 (SELECT js.statusid
                                                    FROM api.jobstatuses js
                                                   WHERE js.jobtypeid =
                                                         t_licensedefid
                                                     AND js.statustype != 'X'
                                                     AND js.statustype != 'C'))
                               WHERE r1.toobjectid = t_personobjid
                                 AND r2.fromobjectid <> t_masterleobjid -- TODO 05.060.2008 TEST THIS
                                 AND r1.endpointid = t_lepersonep
                                 AND lic.objectid <> t_jobid)
                LOOP
                    -- relate Licensee Person Legal Entity as P12 Candidate
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_convertleep,
                                                       t_processobjid,
                                                       c_lep.leobjid);
                END LOOP;             -- Person Legal Entities for License Job

                FOR c_lep IN (SELECT -- Find all the Legal Entities associated with this Person which are Applicants
                                     r1.fromobjectid leobjid, app.jobid
                                FROM api.relationships  r1
                                     JOIN api.relationships r2
                                         ON (r2.fromobjectid =
                                             r1.fromobjectid
                                         AND r2.endpointid =
                                             t_leapplicationep)
                                     JOIN query.j_application app
                                         ON (app.objectid = r2.toobjectid
                                         AND app.statusid IN
                                                 (SELECT js.statusid
                                                    FROM api.jobstatuses  js
                                                         JOIN api.statuses s
                                                             ON s.statusid =
                                                                js.statusid
                                                   WHERE js.jobtypeid =
                                                         t_applicationdefid --app.jobtypeid
                                                     AND s.tag IN ('NEW',
                                                                   'PEND',
                                                                   'APPLD',
                                                                   'DENIED')))
                               WHERE r1.toobjectid = t_personobjid
                                 AND r2.fromobjectid <> t_masterleobjid -- TODO 05.060.2008 TEST THIS
                                 AND r1.endpointid = t_lepersonep)
                LOOP
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(t_convertleep,
                                                       t_processobjid,
                                                       c_lep.leobjid);
                END LOOP;         -- Person Legal Entities for Application Job
        END;

        -- Set Flag to show Procedure has been ran.
        api.pkg_columnupdate.setvalue(t_processobjid,
                                      'RelateLEHasRunBefore',
                                      'Y');
    END relateletoprocessforp12;

    /*---------------------------------------------------------------------------
     * ChangeP12Address() - PUBLIC
     *  Used on completion of the p_ChangeP12MailingAddress process to change the
     *  mailing address on the License job.
     *-------------------------------------------------------------------------*/
    PROCEDURE changep12address(a_processid udt_id, a_asofdate DATE)
    IS
        t_jobid          udt_id;
        t_procaddrid     udt_id;
        t_jobaddrrelid   udt_id;
        t_relid          udt_id;
    BEGIN
        SELECT p.jobid
          INTO t_jobid
          FROM api.processes p
         WHERE p.processid = a_processid;

        -- Pull the Mailing Address off of the process, if it doesn't exist, throw
        -- an error so we can't complete the process.
        BEGIN
            SELECT cpaa.addressid
              INTO t_procaddrid
              FROM query.r_changep12addrtoaddr cpaa
             WHERE cpaa.changep12mailingaddressid = a_processid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'Please select an Address before completing process.');
        END;

        -- Remove the Mailing Address on the License job, if it doesn't exist, do nothing.
        BEGIN
            SELECT lam.relationshipid
              INTO t_jobaddrrelid
              FROM query.r_licenseaddrmailing lam
             WHERE lam.licensejobid = t_jobid;

            api.pkg_relationshipupdate.remove(t_jobaddrrelid);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        -- Add the new Mailing Address
        t_relid   :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('j_License',
                                                      'MailingAddress'),
                t_jobid,
                t_procaddrid);
    END changep12address;

    ---------------------------------------------------------------------------------------------------
    --   * ConvertLEToP12() -- PUBLIC
    -- Called at completion of process p_convertLEtoP12.
    -- Sets P12 status on P12 Master Legal Entity.
    -- Sets P12 Master status on P12 Master License.
    -- For Each Legal Entity candidate related to process, removes existing LE Licensee and relates
    -- to Master P12 Legal Entity
    ---------------------------------------------------------------------------------------------------
    PROCEDURE convertletop12(a_processobjectid udt_id, a_asofdate DATE)
    IS
        t_mlecheckid              NUMBER;
        t_lestodelete             udt_objectlist;
        t_proceduraldeletionid    NUMBER;
        t_removerel               NUMBER;
        t_newrel                  udt_id;
        t_masteraddressid         NUMBER;
        t_overrideaddressupdate   BOOLEAN := FALSE;
    BEGIN
        -- Verify that there is a Master Legal Entity Related to the ConvertLEToP12 process (cardinality is not used
        -- because that legal entity is delected when the Person/Company related to the Master Legal Entity is
        -- already a P12 on another License.
        SELECT COUNT(mle.relationshipid)
          INTO t_mlecheckid
          FROM query.r_convertletop12masterle mle
         WHERE mle.convertletop12processid = a_processobjectid;

        IF t_mlecheckid = 0 THEN
            api.pkg_errors.raiseerror(
                -20000,
                'This process must have a P12 Master LE selected before completion.');
        END IF;


        --Identify the Master Legal Entity, as defined by the Convert P12 Process
        --Person: Select P12 Master LE Object Id and License Job into MasterLEObjId and MasterLicObjId from pre-existing
        --Master Legal Entity (for when P12 License already exists for this Person).
        BEGIN
            SELECT le1.objectid, rpp.p12licensejobid
              INTO t_masterleobjid, t_masterlicobjid
              FROM query.r_convertletop12masterle  rcl
                   JOIN query.r_legalentityperson rlp
                       ON rlp.legalentityobjectid = rcl.legalentityobjectid
                   JOIN query.r_p12licenseperson rpp
                       ON rpp.p12personobjectid = rlp.personobjectid
                   JOIN query.r_licenseprimaryp12legalentity rlep
                       ON rlep.licensejobid = rpp.p12licensejobid
                   JOIN query.o_legalentity le1
                       ON le1.objectid = rlep.primayrp12leobjectid
             WHERE rcl.convertletop12processid = a_processobjectid
               AND le1.p12status = 'Y'
               AND api.pkg_columnquery.VALUE(rpp.p12licensejobid,
                                             'ThisLicenseIsP12Master') =
                   'Y'
               AND le1.objectid = rcl.legalentityobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;

                --Company: Select P12 Master LE Object Id and License Job into MasterLEObjId and MasterLicObjId from pre-existing
                --Master Legal Entity (for when P12 License already exists for this Company).

                BEGIN
                    SELECT le2.objectid, rpc.p12licensejobid
                      INTO t_masterleobjid, t_masterlicobjid
                      FROM query.r_convertletop12masterle  rcl2
                           JOIN query.r_legalentitycompany rlc
                               ON rlc.legalentityobjectid =
                                  rcl2.legalentityobjectid
                           JOIN query.r_p12licensecompany rpc
                               ON rpc.p12companyobjectid =
                                  rlc.companyobjectid
                           JOIN query.r_licenseprimaryp12legalentity rlep
                               ON rlep.licensejobid = rpc.p12licensejobid
                           JOIN query.o_legalentity le2
                               ON le2.objectid = rlep.primayrp12leobjectid
                     WHERE rcl2.convertletop12processid = a_processobjectid
                       AND le2.p12status = 'Y'
                       AND api.pkg_columnquery.VALUE(
                               rpc.p12licensejobid,
                               'ThisLicenseIsP12Master') =
                           'Y'
                       AND le2.objectid = rcl2.legalentityobjectid;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        --When there is no pre-existing P12 Master Legal Entity, substitute into t_MasterLEObjId the le.objectid of the
                        --Legal Entity selected by the user in the Master Legal Entity Relationship and set the License and Legal Entity as the Masters.
                        BEGIN
                            SELECT r.toobjectid
                              INTO t_masterleobjid
                              FROM api.relationships r
                             WHERE r.fromobjectid = a_processobjectid
                               AND r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'p_ConvertLEToP12',
                                       'MasterLegalEntity');

                            -- Identify the Master License
                            SELECT p.jobid
                              INTO t_masterlicobjid
                              FROM api.processes p
                             WHERE p.processid = a_processobjectid;

                            BEGIN
                                SELECT r.relationshipid
                                  INTO t_removerel
                                  FROM query.r_licenseprimaryp12legalentity r
                                 WHERE r.licensejobid = t_masterlicobjid;

                                api.pkg_relationshipupdate.remove(
                                    t_removerel);
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    dbms_output.put_line(
                                        'No Old Primary Relationship to delete');
                            END;

                            -- Set P12 Master indicator on License
                            api.pkg_columnupdate.setvalue(
                                t_masterlicobjid,
                                'ThisLicenseIsP12Master',
                                'Y');
                            -- Create Self-referential rel so we can quickly access the P12Master
                            --   License using Oracle joins
                            t_newrel   :=
                                api.pkg_relationshipupdate.new(
                                    gc_p12selfep,
                                    t_masterlicobjid,
                                    t_masterlicobjid);
                            -- Set P12 Master indicator on Legal Entity
                            api.pkg_columnupdate.setvalue(t_masterleobjid,
                                                          'P12Status',
                                                          'Y');

                            -- Set up Master Legal Entity Relationship
                            SELECT relationshipid
                              INTO t_removerelletolic
                              FROM api.relationships
                             WHERE fromobjectid = t_masterlicobjid
                               AND toobjectid = t_masterleobjid
                               AND endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_License',
                                       'LicenseeLegalEntity');

                            -- Remove Licensee relationship to Master License.
                            api.pkg_relationshipupdate.remove(
                                t_removerelletolic);

                            -- Relate the Master P12 Legal Entity to the P12 Master License.
                            t_newrelobjectid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_License',
                                        'P12Licensee'),
                                    t_masterlicobjid,
                                    t_masterleobjid);
                        END;
                END;
        END;

        t_proceduraldeletionid   :=
            api.pkg_configquery.columndefidforname('o_LegalEntity',
                                                   'ProceduralDeletion');

        -- If the Master License is or will be the license that the ConvertLEToP12 is being run on, then Convert Licenses
        -- and Applications to relate to the selected Master Legal Entity and delete the other legal entities related to
        -- the Process.
        IF t_masterlicobjid =
           api.pkg_columnquery.VALUE(a_processobjectid, 'JobId')
        OR t_masterleobjid =
           api.pkg_columnquery.VALUE(a_processobjectid, 'ProcessMLEObjectId') THEN
            BEGIN
                SELECT la.maobjectid
                  INTO t_masteraddressid
                  FROM query.r_licenseaddrmailing la
                 WHERE la.licensejobid = t_masterlicobjid;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'This License needs a mailing address before this Legal Entity can be converted to P12.');
            END;

            -- find LE object ids that are related to the ConvertLEToP12 process.
            FOR c_1
                IN (SELECT r.toobjectid leobjid
                      FROM api.relationships r
                     WHERE fromobjectid = a_processobjectid   --t_ProcessObjId
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'p_ConvertLEToP12',
                               'LEConvertingToP12'))
            LOOP
                BEGIN
                    -- find license to which the LE is related
                    SELECT fromobjectid
                      INTO t_licobjid
                      FROM api.relationships
                     WHERE toobjectid = c_1.leobjid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_License',
                               'LicenseeLegalEntity');

                    --Remove Legal Entity's Children
                    t_lestodelete   := api.udt_objectlist();
                    sitespecific.pkg_legalentity.getlegalentitychildren(
                        c_1.leobjid,
                        t_lestodelete);

                    FOR c_2 IN 1 .. t_lestodelete.COUNT
                    LOOP
                        api.pkg_objectupdate.remove(
                            t_lestodelete(c_2).objectid);
                    END LOOP;

                    -- Remove Legal Entity object
                    api.pkg_objectupdate.remove(c_1.leobjid);

                    -- Relate the License to the Master P12 Legal Entity
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'P12Licensee'),
                            t_licobjid,
                            t_masterleobjid);

                    createprimaryp12ifnewlic(t_newrelobjectid, SYSDATE, NULL);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- find application to which the LE is related
                        SELECT fromobjectid
                          INTO t_licobjid
                          FROM api.relationships
                         WHERE toobjectid = c_1.leobjid
                           AND endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_Application',
                                   'Applicant');


                        --Remove Legal Entity's Children
                        t_lestodelete   := api.udt_objectlist();
                        sitespecific.pkg_legalentity.getlegalentitychildren(
                            c_1.leobjid,
                            t_lestodelete);

                        FOR c_2 IN 1 .. t_lestodelete.COUNT
                        LOOP
                            api.pkg_objectupdate.remove(
                                t_lestodelete(c_2).objectid);
                        END LOOP;

                        -- Remove Legal Entity object
                        api.pkg_objectupdate.remove(c_1.leobjid);

                        -- Relate the Application to the Master P12 Legal Entity
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_Application',
                                    'P12Applicant'),
                                t_licobjid,
                                t_masterleobjid);

                        createprimaryp12ifnewapp(t_newrelobjectid,
                                                 SYSDATE,
                                                 NULL);
                END;
            END LOOP; -- Convert Licenses to relate to Master P12 Legal Entity
        ELSE
            -- If there is already a Master License and it is not the ConvertLEToP12's License job, then include MLE selected
            -- on process in the delection of Legal Entities and relate the ConvertLEToP12's License License job to the
            -- existing P12 Master Legal Entity along with the other LE's jobs.
            FOR c_1
                IN (SELECT r.toobjectid leobjid
                      FROM api.relationships r
                     WHERE fromobjectid = a_processobjectid   --t_ProcessObjId
                       AND (endpointid =
                            api.pkg_configquery.endpointidforname(
                                'p_ConvertLEToP12',
                                'LEConvertingToP12')
                         OR endpointid =
                            api.pkg_configquery.endpointidforname(
                                'p_ConvertLEToP12',
                                'MasterLegalEntity')))
            LOOP
                BEGIN
                    -- find license to which the LE is related
                    SELECT fromobjectid
                      INTO t_licobjid
                      FROM api.relationships
                     WHERE toobjectid = c_1.leobjid
                       AND endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_License',
                               'LicenseeLegalEntity');

                    -- Relate the License to the Master P12 Legal Entity, unless the License already has a P12 Licensee
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'P12Licensee'),
                            t_licobjid,
                            t_masterleobjid);

                    --Remove Legal Entity's Children when License doesn't already have a P12 Licensee
                    t_lestodelete   := api.udt_objectlist();
                    sitespecific.pkg_legalentity.getlegalentitychildren(
                        c_1.leobjid,
                        t_lestodelete);

                    FOR c_2 IN 1 .. t_lestodelete.COUNT
                    LOOP
                        api.pkg_objectupdate.remove(
                            t_lestodelete(c_2).objectid);
                    END LOOP;

                    --Remove Legal Entity object when License doesn't already have a P12 Licensee
                    api.pkg_objectupdate.remove(c_1.leobjid);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- find application to which the LE is related
                        SELECT fromobjectid
                          INTO t_licobjid
                          FROM api.relationships
                         WHERE toobjectid = c_1.leobjid
                           AND endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_Application',
                                   'Applicant');

                        -- Relate the Application to the Master P12 Legal Entity, unless the Application already has a P12 Applicant
                        t_newrelobjectid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'j_Application',
                                    'P12Applicant'),
                                t_licobjid,
                                t_masterleobjid);

                        createprimaryp12ifnewapp(t_newrelobjectid,
                                                 SYSDATE,
                                                 NULL);  --t_MasterAddressId);

                        --Remove Legal Entity's Children when Application doesn't already have a P12 Applicant
                        t_lestodelete   := api.udt_objectlist();
                        sitespecific.pkg_legalentity.getlegalentitychildren(
                            c_1.leobjid,
                            t_lestodelete);

                        FOR c_2 IN 1 .. t_lestodelete.COUNT
                        LOOP
                            api.pkg_objectupdate.remove(
                                t_lestodelete(c_2).objectid);
                        END LOOP;

                        -- Remove Legal Entity when Application doesn't already have a P12 Applicant
                        api.pkg_objectupdate.remove(c_1.leobjid);
                END;
            END LOOP; -- Convert Licenses to relate to Master P12 Legal Entity
        END IF;
    END convertletop12;

    ---------------------------------------------------------------------------------------------------
    --   * ConvertLEToP12() -- PUBLIC
    -- Called at completion of process p_convertP12toLE.
    -- Sets P12 status on P12 Master Legal Entity.
    -- Sets P12 Master status on P12 Master License.
    -- For Each Legal Entity candidate related to process, removes existing LE Licensee and relates
    -- to Master P12 Legal Entity
    ---------------------------------------------------------------------------------------------------
    procedure ConvertP12ToLE(
      a_ProcessObjectId       udt_id,
      a_AsOfDate        date
     )is
      t_P12MasterJobId     udt_id;
      t_RaiseErrorPerson   boolean := False;
      t_RaiseErrorCompany  boolean := False;
      t_p12aMasterLEId     udt_Id := null;
      t_LegalEntities      api.pkg_definition.udt_IdList; 
    begin
     -- Verify that there is a Master Legal Entity Related to the ConvertLEToP12 process (cardinality is not used
     -- because that legal entity is delected when the Person/Company related to the Master Legal Entity is
     -- already a P12 on another License.
     -- Identify the Master Legal Entity, as defined by the Convert P12 Process

        --Person: Select P12 Master LE Object Id and License Job into MasterLEObjId and MasterLicObjId from pre-existing
        --Master Legal Entity

        begin
        select le1.ObjectId, rpp.P12LicenseJobId into t_MasterLEObjId, t_P12MasterJobId
         from query.r_convertP12toLeRel rcl
         join query.r_legalentityperson rlp on rlp.LegalEntityObjectId = rcl.LegalEntityObjectId
         join query.r_P12LicensePerson rpp on rpp.P12PersonObjectId = rlp.PersonObjectId
         join query.r_LicensePrimaryP12LegalEntity rlep on rlep.LicenseJobId =  rpp.P12LicenseJobId
         join query.o_legalentity le1 on le1.ObjectId = rlep.PrimayrP12LEObjectId
         where rcl.ConvertP12toLEProcessId = a_ProcessObjectId
         and le1.P12Status = 'Y'
         and api.pkg_columnquery.value(rpp.P12LicenseJobId, 'ThisLicenseIsP12Master') = 'Y'
         and le1.ObjectId = rcl.LegalEntityObjectId;

         EXCEPTION WHEN NO_DATA_FOUND THEN
           t_RaiseErrorPerson := True;
         end;

        --Company: Select P12 Master LE Object Id and License Job into MasterLEObjId and MasterLicObjId from pre-existing
        --Master Legal Entity (for when P12 License already exists for this Company).

         begin
         select le2.ObjectId, rpc.P12LicenseJobId into  t_MasterLEObjId, t_P12MasterJobId
          from query.r_convertP12toLeRel rcl2
          join query.r_legalentitycompany rlc on rlc.LegalEntityObjectId = rcl2.LegalEntityObjectId
          join query.r_P12LicenseCompany rpc on rpc.P12CompanyObjectId = rlc.CompanyObjectId
          join query.r_LicensePrimaryP12LegalEntity rlep on rlep.LicenseJobId = rpc.P12LicenseJobId
          join query.o_legalentity le2 on le2.ObjectId = rlep.PrimayrP12LEObjectId
          where rcl2.ConvertP12toLEProcessId = a_ProcessObjectId
          and le2.P12Status = 'Y'
          and api.pkg_columnquery.value(rpc.P12LicenseJobId, 'ThisLicenseIsP12Master') = 'Y'
          and le2.ObjectId = rcl2.LegalEntityObjectId;

         EXCEPTION WHEN NO_DATA_FOUND THEN
           t_RaiseErrorCompany := True;
         end;

         if t_RaiseErrorPerson and t_RaiseErrorCompany then
           api.pkg_errors.RaiseError(-20000, 'This process must have a P12 LE selected before completion.');
         end if;

         begin
           select r.ToObjectId
           into   t_MasterLEObjId
           from api.relationships r
           where r.FromObjectId = a_ProcessObjectId
           and r.EndPointId = api.pkg_configquery.EndPointIdForName(
                         'p_ConvertP12toLE', 'MasterLegalEntity')
           and api.pkg_columnquery.Value(r.ToObjectId, 'P12Status') = 'Y';
         exception when no_data_found then
           api.pkg_errors.RaiseError(-20001, 'There are no legal entities to convert.');
         end;
         
       --get all children of the p12
       t_LegalEntities := sitespecific.pkg_LegalEntity.GetJobLEChildren ( t_P12MasterJobId );
       --find the p12a master
       for i in ( select le.Column_Value
                    from table( t_LegalEntities ) le ) loop
         if t_p12aMasterLEId is null then
           t_p12aMasterLEId := api.pkg_ColumnQuery.NumericValue( i.Column_Value , 'P12AMasterLEId' );
         else
           exit;
         end if;
       end loop;     

       if api.pkg_columnquery.Value(a_ProcessObjectId, 'ConvertAllToLegalEntities') = 'N' then

         if t_P12MasterJobId = api.pkg_columnquery.Value(a_ProcessObjectId,'JobId') then
           api.pkg_errors.RaiseError(-20001, 'You must convert all Licensees to a Legal Entity, when running this process on the master License');
         end if;
       
         -- Identify the Current License
         select p.JobId into t_MasterLicObjId
          from api.processes p
          where p.ProcessId = a_ProcessObjectId;

         -- Set up Legal Entity Relationship
         select RelationshipId into t_RemoveRelLEtoLic
          from api.relationships
          where FromObjectId = t_MasterLicObjId
          and ToObjectId = t_MasterLEObjId
          and EndPointId = api.pkg_configquery.EndPointIdForName('j_License', 'P12Licensee');

         sitespecific.pkg_legalentity.LegalEntityLookupCopy(t_RemoveRelLEtoLic,sysdate,'','LicenseeLegalEntity');
                                                                                          
      else

       for e in (select lep.relationshipid, lep.ObjectDefname, lep.LicenseJobId JobId
                   from query.r_LicenseP12LegalEntity lep
                  where lep.LegalEntityObjectId = t_MasterLEObjId
                   union
                 select ale.RelationshipId, ale.ObjectDefname, ale.ApplicationJobId JobId
                   from query.r_ApplicationP12LegalEntity ale
                  where ale.LegalEntityObjectId = t_MasterLEObjId ) loop
                  
                  
           sitespecific.pkg_legalentity.LegalEntityLookupCopy(e.Relationshipid,
                                                               sysdate,'',
                                                               case when e.objectdefname = 'r_LicenseP12LegalEntity'
                                                                 then 'LicenseeLegalEntity'
                                                                    when e.objectdefname = 'r_ApplicationP12LegalEntity'
                                                                 then 'Applicant'
                                                               end);

           if e.objectdefname = 'r_ApplicationP12LegalEntity' then
             DeletePrimaryP12App(e.Jobid);
           else
             DeletePrimaryP12Lic(e.JobId);
           end if;

       end loop;
             
        api.pkg_columnupdate.SetValue(t_P12MasterJobId, 'ThisLicenseIsP12Master', 'N');
        api.pkg_objectupdate.Remove(t_MasterLEObjId); 
        
      end if;

      /*
      SG: ISSUE0038526 - Scenario #1 Fix 
      When converting p12 legal entities on this license, if this license is the p12a master then some additional cleanup needs 
      to be happening because the p12a master legal entity has been replaced on the license.
      */
      if t_p12aMasterLEId > 0 then
        sitespecific.pkg_p12a.UpdateP12AMasterLE( t_p12aMasterLEId, sysdate );
      end if;     

    end ConvertP12ToLE;

    ---------------------------------------------------------------------------------------------------
    --   * SyncExprDateOnP12() -- PUBLIC
    -- Update the non-seasonal License Types related to the P12 License.
    -- The ExpiringMonth and the ExpiringYear are updated to the values on the Process.
    ---------------------------------------------------------------------------------------------------
    PROCEDURE syncexprdateonp12(a_processobjectid udt_id,
                                a_asofdate      DATE,
                                a_jobid         udt_id,
                                a_expirationmonth VARCHAR2,
                                a_expirationyear INTEGER)
    AS
        t_isp12master          CHAR;
        t_p12masterlicenseno   udt_id;
    BEGIN
        t_isp12master   :=
            api.pkg_columnquery.VALUE(a_jobid, 'ThisLicenseIsP12Master');
        t_p12masterlicenseno   :=
            api.pkg_columnquery.numericvalue(a_jobid, 'P12MasterLicenseNo');

        IF (t_isp12master = 'Y')
        OR (t_p12masterlicenseno IS NOT NULL) THEN
            FOR c
                IN (SELECT rllt.licensetypejobid
                      FROM query.r_licenselicensetype rllt
                     WHERE rllt.licensejobid IN
                               (SELECT rlple2.licensejobid
                                  FROM query.r_licensep12legalentity  rlple1
                                       JOIN
                                       query.r_licensep12legalentity rlple2
                                           ON rlple2.legalentityobjectid =
                                              rlple1.legalentityobjectid
                                 WHERE rlple1.licensejobid = a_jobid))
            LOOP
                IF (api.pkg_columnquery.numericvalue(
                        c.licensetypejobid,
                        'SeasonStartMonthNumber')
                        IS NULL) THEN
                    api.pkg_columnupdate.setvalue(c.licensetypejobid,
                                                  'ExpiringMonth',
                                                  a_expirationmonth);
                    api.pkg_columnupdate.setvalue(c.licensetypejobid,
                                                  'ExpiringYear',
                                                  a_expirationyear);
                END IF;
            END LOOP;
        ELSE
            api.pkg_errors.raiseerror(
                2000,
                'The License is not a P12 License, no License Types updated');
        END IF;
    END syncexprdateonp12;

    /*----------------------------------------------------------
     * RemoveMasterP12Error()     --Public
     * This will rasie an error when the Rel between the Application and the P12LE is removed
     * AND the License is a P12 Master.
     *---------------------------------------------------------*/

    PROCEDURE removemasterp12error(a_objectid udt_id, a_asofdate DATE)
    IS
        t_applicationobjectid   udt_id;
        t_isp12master           VARCHAR(1);
        t_applicationtype       VARCHAR(60);
    BEGIN
        BEGIN
            SELECT ale.applicationjobid,
                   l.thislicenseisp12master,
                   a.applicationtype
              INTO t_applicationobjectid, t_isp12master, t_applicationtype
              FROM query.r_applicationp12legalentity  ale
                   JOIN query.j_application a
                       ON a.jobid = ale.applicationjobid
                   JOIN query.r_applicationlicense al
                       ON a.jobid = al.applicationjobid
                   JOIN query.j_license l ON al.licensejobid = l.jobid
             WHERE ale.relationshipid = a_objectid;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        IF t_isp12master = 'Y'
       AND t_applicationtype = 'Change' THEN
            api.pkg_errors.raiseerror(
                -20000,
                'The P12 Legal Entity cannot be removed from a Change Application when the change is against the P12 Master License.');
        END IF;
    END removemasterp12error;

    /*--------------------
    -- UpdateP12MAFromProcess() - PUBLIC
    -- This procedure is to be run as a deffered procedure on completion of the Change P12 Master License
    -- and Convert LE to P12 processes. This will check the new P12 Master License and make that License's
    -- Mailing Address the address for all the children Licenses. This includes deleting the children
    -- Mailing Addresses if the Master License does not have one.
    */
    --------------------

    PROCEDURE updatep12mafromprocess(a_objectid udt_id, a_asofdate DATE)
    IS
        t_addressid        udt_id;
        t_licensejobid     udt_id;
        t_otheraddressid   udt_id;
        t_otherrelid       udt_id;
        t_relid            udt_id;
        t_endpointid       udt_id;
    BEGIN
        IF api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName') =
           'p_ChangeP12MasterLicense' THEN
            -- Get the new Master License Job Id and it's Mailing Address rel Id
            SELECT l.licensejobid, lma.maobjectid
              INTO t_licensejobid, t_addressid
              FROM query.r_newp12masterlicense  l
                   LEFT OUTER JOIN query.r_licenseaddrmailing lma
                       ON l.licensejobid = lma.licensejobid
             WHERE l.changep12masterlicprocessid = a_objectid;
        ELSIF api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName') =
              'p_ConvertLEToP12' THEN
            -- Get the LicenseJobId and Address Id from the process
            SELECT cl.jobid, lma.maobjectid
              INTO t_licensejobid, t_addressid
              FROM query.p_convertletop12  cl
                   LEFT OUTER JOIN query.r_licenseaddrmailing lma
                       ON cl.jobid = lma.licensejobid
             WHERE cl.objectid = a_objectid;
        END IF;

        IF api.pkg_columnquery.VALUE(t_licensejobid,
                                     'ThisLicenseIsP12Master') =
           'Y' THEN
            IF t_addressid IS NULL THEN
                -- Loop through related P12 Licenses/Applications and update the Mailing Address rels on those
                FOR c
                    IN (SELECT lma.relationshipid
                          FROM query.j_license  ml
                               JOIN query.r_licensep12legalentity lmple
                                   ON lmple.licensejobid = ml.jobid
                               JOIN query.r_licensep12legalentity lple
                                   ON lmple.legalentityobjectid =
                                      lple.legalentityobjectid
                               JOIN query.r_licenseaddrmailing lma
                                   ON lple.licensejobid = lma.licensejobid
                         WHERE ml.jobid = t_licensejobid
                           AND lma.licensejobid != t_licensejobid
                        UNION ALL
                        SELECT ama.relationshipid
                          FROM query.j_license  ml
                               JOIN query.r_licensep12legalentity lmple
                                   ON ml.jobid = lmple.licensejobid
                               JOIN query.r_applicationp12legalentity aple
                                   ON lmple.legalentityobjectid =
                                      aple.legalentityobjectid
                               JOIN query.r_applicationmailaddr ama
                                   ON aple.applicationjobid =
                                      ama.applicationjobid
                         WHERE ml.jobid = t_licensejobid
                           AND api.pkg_columnquery.numericvalue(
                                   ama.applicationjobid,
                                   'StatusId') IN
                                   (SELECT js.statusid
                                      FROM api.jobstatuses js
                                     WHERE js.statustype IN ('I', 'O')))
                LOOP
                    -- Remove the Mailing Address rel
                    api.pkg_relationshipupdate.remove(c.relationshipid);
                END LOOP;
            ELSIF t_addressid IS NOT NULL THEN
                -- Loop through related P12 Licenses and update the Mailing Address rels on those
                FOR c
                    IN (SELECT l.jobid
                          FROM query.j_license  ml
                               JOIN query.r_licensep12legalentity lmple
                                   ON lmple.licensejobid = ml.jobid
                               JOIN query.r_licensep12legalentity lple
                                   ON lmple.legalentityobjectid =
                                      lple.legalentityobjectid
                               JOIN query.j_license l
                                   ON l.jobid = lple.licensejobid
                         WHERE ml.jobid = t_licensejobid
                           AND l.jobid != t_licensejobid
                        UNION ALL
                        SELECT a.jobid
                          FROM query.j_license  ml
                               JOIN query.r_licensep12legalentity lmple
                                   ON ml.jobid = lmple.licensejobid
                               JOIN query.r_applicationp12legalentity aple
                                   ON lmple.legalentityobjectid =
                                      aple.legalentityobjectid
                               JOIN query.j_application a
                                   ON aple.applicationjobid = a.jobid
                         WHERE ml.jobid = t_licensejobid
                           AND a.statusid IN
                                   (SELECT js.statusid
                                      FROM api.jobstatuses js
                                     WHERE js.statustype IN ('I', 'O')))
                LOOP
                    -- Get the endpoint Id
                    IF api.pkg_columnquery.VALUE(c.jobid, 'ObjectDefName') =
                       'j_License' THEN
                        t_endpointid   :=
                            api.pkg_configquery.endpointidforname(
                                'j_License',
                                'MailingAddress');
                    ELSIF api.pkg_columnquery.VALUE(c.jobid, 'ObjectDefName') =
                          'j_Application' THEN
                        t_endpointid   :=
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'MailingAddress');
                    END IF;

                    BEGIN
                        -- check if the Mailing Addr rel already exists on the License
                        SELECT lma.relationshipid, lma.maobjectid
                          INTO t_otherrelid, t_otheraddressid
                          FROM query.r_licenseaddrmailing lma
                         WHERE lma.licensejobid = c.jobid
                        UNION ALL
                        SELECT ama.relationshipid, ama.addressobjectid
                          FROM query.r_applicationmailaddr ama
                         WHERE ama.applicationjobid = c.jobid;

                        IF t_otheraddressid != t_addressid THEN
                            -- Remove old rel
                            api.pkg_relationshipupdate.remove(t_otherrelid);
                            -- Create the new one
                            t_relid   :=
                                api.pkg_relationshipupdate.new(t_endpointid,
                                                               c.jobid,
                                                               t_addressid);
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            -- create a new rel
                            t_relid   :=
                                api.pkg_relationshipupdate.new(t_endpointid,
                                                               c.jobid,
                                                               t_addressid);
                    END;
                END LOOP;
            ELSE
                NULL;
            END IF;
        END IF;
    END updatep12mafromprocess;

    /*********************
    -- RelateP12MailingAddr() - PUBLIC
    -- This is to run on constructor of the License/MailingAddress relationship
    -- and if the License is a P12 Master, it will create/update the Mailing
    -- Address rels on all the other related P12 Licenses/Applications to
    -- match the new Mailing Address rel on the P12 Master License.
    *********************/

    PROCEDURE relatep12mailingaddr(a_objectid udt_id, a_asofdate DATE)
    IS
        t_addressid        udt_id;
        t_licensejobid     udt_id;
        t_otheraddressid   udt_id;
        t_otherrelid       udt_id;
        t_relid            udt_id;
        t_endpointid       udt_id;
    BEGIN
        IF api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName') =
           'r_LicenseAddrMailing' THEN
            -- Get LicenseJobId and Mailing Address Id from rel
            SELECT r.licensejobid, r.maobjectid
              INTO t_licensejobid, t_addressid
              FROM query.r_licenseaddrmailing r
             WHERE r.relationshipid = a_objectid;
        END IF;

        IF api.pkg_columnquery.VALUE(t_licensejobid,
                                     'ThisLicenseIsP12Master') =
           'Y'
       AND t_addressid IS NOT NULL THEN
            -- Loop through related P12 Licenses and update the Mailing Address rels on those
            FOR c
                IN (SELECT child.licensejobid jobid
                      FROM (SELECT lple.primayrp12leobjectid
                              FROM query.r_licenseprimaryp12legalentity lple
                             --from query.r_LicenseP12LegalEntity lple
                             WHERE lple.licensejobid = t_licensejobid)
                           parent
                           /* join query.r_LicenseP12LegalEntity child
                              on parent.LegalEntityObjectId = child.LegalEntityObjectId*/
                           JOIN query.r_licenseprimaryp12legalentity child
                               ON parent.primayrp12leobjectid =
                                  child.primayrp12leobjectid
                     WHERE child.licensejobid != t_licensejobid
                    UNION ALL
                    SELECT a.objectid
                      FROM query.r_licenseprimaryp12legalentity  lple
                           --from query.r_LicenseP12LegalEntity lple
                           JOIN query.r_applicationprip12legalentity aple
                               ON aple.primaryp12leobjectid =
                                  lple.primayrp12leobjectid
                           /*join query.r_ApplicationP12LegalEntity aple
                             on lple.LegalEntityObjectId = aple.LegalEntityObjectId*/
                           JOIN query.j_application a
                               ON aple.applicationjobid = a.objectid
                     WHERE lple.licensejobid = t_licensejobid
                       AND a.statusid IN (SELECT js.statusid
                                            FROM api.jobstatuses js
                                           WHERE js.statustype IN ('I', 'O')))
            LOOP
                -- Get the endpoint Id
                IF api.pkg_columnquery.VALUE(c.jobid, 'ObjectDefName') =
                   'j_License' THEN
                    t_endpointid   :=
                        api.pkg_configquery.endpointidforname(
                            'j_License',
                            'MailingAddress');
                ELSIF api.pkg_columnquery.VALUE(c.jobid, 'ObjectDefName') =
                      'j_Application' THEN
                    t_endpointid   :=
                        api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'MailingAddress');
                END IF;

                BEGIN
                    -- check if the Mailing Addr rel already exists on the License
                    SELECT lma.relationshipid, lma.maobjectid
                      INTO t_otherrelid, t_otheraddressid
                      FROM query.r_licenseaddrmailing lma
                     WHERE lma.licensejobid = c.jobid
                    UNION ALL
                    SELECT ama.relationshipid, ama.addressobjectid
                      FROM query.r_applicationmailaddr ama
                     WHERE ama.applicationjobid = c.jobid;

                    IF t_otheraddressid != t_addressid THEN
                        -- Remove old rel
                        api.pkg_relationshipupdate.remove(t_otherrelid);
                        -- Create the new one
                        t_relid   :=
                            api.pkg_relationshipupdate.new(t_endpointid,
                                                           c.jobid,
                                                           t_addressid);
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- create a new rel
                        t_relid   :=
                            api.pkg_relationshipupdate.new(t_endpointid,
                                                           c.jobid,
                                                           t_addressid);
                END;
            END LOOP;
        END IF;
    END relatep12mailingaddr;

    /*********************
    -- RelateP12MailingAddr() - PUBLIC
    -- This is to run on destructor of the License/MailingAddress relationship
    -- and if the License is a P12 Master, it will remove the Mailing
    -- Address rels on all the other related P12 Licenses/Applications.
    *********************/

    PROCEDURE removep12mailingaddr(a_objectid udt_id, a_asofdate DATE)
    IS
        t_licensejobid   udt_id;
    BEGIN
        BEGIN
            SELECT r.licensejobid
              INTO t_licensejobid
              FROM p12addrlic_t r
             WHERE r.relationshipid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        IF api.pkg_columnquery.VALUE(t_licensejobid,
                                     'ThisLicenseIsP12Master') =
           'Y' THEN
            -- Loop through related P12 Licenses/Applications and update the Mailing Address rels on those
            FOR c
                IN (SELECT lma.relationshipid
                      FROM query.j_license  ml
                           JOIN query.r_licensep12legalentity lmple
                               ON lmple.licensejobid = ml.jobid
                           JOIN query.r_licensep12legalentity lple
                               ON lmple.legalentityobjectid =
                                  lple.legalentityobjectid
                           JOIN query.r_licenseaddrmailing lma
                               ON lple.licensejobid = lma.licensejobid
                     WHERE ml.jobid = t_licensejobid
                       AND lma.licensejobid != t_licensejobid
                    UNION ALL
                    SELECT ama.relationshipid
                      FROM query.j_license  ml
                           JOIN query.r_licensep12legalentity lmple
                               ON ml.jobid = lmple.licensejobid
                           JOIN query.r_applicationp12legalentity aple
                               ON lmple.legalentityobjectid =
                                  aple.legalentityobjectid
                           JOIN query.r_applicationmailaddr ama
                               ON aple.applicationjobid =
                                  ama.applicationjobid
                     WHERE ml.jobid = t_licensejobid
                       AND api.pkg_columnquery.numericvalue(
                               ama.applicationjobid,
                               'StatusId') IN
                               (SELECT js.statusid
                                  FROM api.jobstatuses js
                                 WHERE js.statustype IN ('I', 'O')))
            LOOP
                -- Remove the Mailing Address rel
                api.pkg_relationshipupdate.remove(c.relationshipid);
            END LOOP;
        END IF;
    END removep12mailingaddr;

    ---------------------------------

    /*---------------------------------------------------------------------------
     * DeleteP12Address() - PUBLIC
     *  Remove a P12 Mailing Address on a given p_ChangeP12MailingAddress process.
     *-------------------------------------------------------------------------*/
    PROCEDURE deletep12address(a_processid udt_id, a_asofdate DATE)
    IS
        t_addrrelid   udt_id;
    BEGIN
        SELECT cpaa.relationshipid
          INTO t_addrrelid
          FROM query.r_changep12addrtoaddr cpaa
         WHERE cpaa.changep12mailingaddressid = a_processid;

        api.pkg_relationshipupdate.remove(t_addrrelid);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- We shouldn't be able to delete a Mailing Address if one doesn't exist,
            -- but just in case...
            NULL;
    END deletep12address;

    PROCEDURE getp12relids(a_objectid udt_id, a_asofdate DATE)
    IS
        t_addressid      udt_id;
        t_licensejobid   udt_id;
    BEGIN
        SELECT r.licensejobid, r.maobjectid
          INTO t_licensejobid, t_addressid
          FROM query.r_licenseaddrmailing r
         WHERE r.relationshipid = a_objectid;

        INSERT INTO p12addrlic_t(relationshipid, addressid, licensejobid)
             VALUES (a_objectid, t_addressid, t_licensejobid);
    END getp12relids;

    /*---------------------------------------------------------------------------
     * Primary P12 Procedural Lookup for License, Used to Select the Primary
     * P12 Legal Entity
     *-------------------------------------------------------------------------*/

    PROCEDURE lookupprimaryp12lic(a_objectid         udt_id,
                                  a_relationshipdefid udt_id,
                                  a_endpoint         VARCHAR2,
                                  a_searchstring     VARCHAR2,
                                  a_objects      OUT udt_objectlist)
    IS
    BEGIN
        SELECT api.udt_object(lle.legalentityobjectid)
          BULK COLLECT INTO a_objects
          FROM query.r_licensep12legalentity lle
         WHERE lle.licensejobid = a_objectid;
    END;

    /*---------------------------------------------------------------------------
     *Primary P12 Procedural Lookup for Application, Used to Select the Primary
     *P12 Legal Entity
     *-------------------------------------------------------------------------*/

    PROCEDURE lookupprimaryp12app(a_objectid         udt_id,
                                  a_relationshipdefid udt_id,
                                  a_endpoint         VARCHAR2,
                                  a_searchstring     VARCHAR2,
                                  a_objects      OUT udt_objectlist)
    IS
    BEGIN
        SELECT api.udt_object(lle2.legalentityobjectid)
          BULK COLLECT INTO a_objects
          FROM query.r_applicationp12legalentity lle2
         WHERE lle2.applicationjobid = a_objectid;
    END;

    /*---------------------------------------------------------------------------
     * LookupDeleteP12Lic Used on the Delete Widget in the Legal Entity Grid to
     * Delete to Correct Relationship
     *-------------------------------------------------------------------------*/

    FUNCTION lookupdeletep12lic(a_licenseobjectid udt_id,
                                a_p12legalentityid udt_id)
        RETURN NUMBER
    IS
        t_p12relid   NUMBER;
    BEGIN
        SELECT lle.relationshipid
          INTO t_p12relid
          FROM query.r_licensep12legalentity lle
         WHERE lle.licensejobid = a_licenseobjectid
           AND lle.legalentityobjectid = a_p12legalentityid;

        RETURN t_p12relid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END;

    /*---------------------------------------------------------------------------
     * LookupDeleteP12App Used on the Delete Widget in the Legal Entity Grid to
     * Delete to Correct Relationship
     *-------------------------------------------------------------------------*/

    FUNCTION lookupdeletep12app(a_applicationobjectid udt_id,
                                a_p12legalentityid udt_id)
        RETURN NUMBER
    IS
        t_p12relid   NUMBER;
    BEGIN
        SELECT lle.relationshipid
          INTO t_p12relid
          FROM query.r_applicationp12legalentity lle
         WHERE lle.applicationjobid = a_applicationobjectid
           AND lle.legalentityobjectid = a_p12legalentityid;

        RETURN t_p12relid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END;

    PROCEDURE createprimaryp12ifnewlic(a_relationshipid udt_id,
                                       a_asofdate      DATE,
                                       a_addressid     NUMBER DEFAULT NULL)
    IS
        t_primaryp12endpoint   udt_id
            := api.pkg_configquery.endpointidforname('j_License',
                                                     'PrimaryP12Licensee');
        t_p12legalentity       udt_id;
        t_relexists            NUMBER;
        t_relid                udt_id;
        t_jobid                udt_id;
        t_endpointid           NUMBER
            := api.pkg_configquery.endpointidforname('j_License',
                                                     'MailingAddress');
    BEGIN
        SELECT r.legalentityobjectid, r.licensejobid
          INTO t_p12legalentity, t_jobid
          FROM query.r_licensep12legalentity r
         WHERE r.relationshipid = a_relationshipid;

        SELECT COUNT(*)
          INTO t_relexists
          FROM api.relationships r
         WHERE r.fromobjectid = t_jobid
           AND r.endpointid = t_primaryp12endpoint
           AND ROWNUM = 1;

        IF t_relexists = 0 THEN
            t_relid   :=
                api.pkg_relationshipupdate.new(t_primaryp12endpoint,
                                               t_jobid,
                                               t_p12legalentity);

            IF a_addressid IS NOT NULL THEN
                propogatep12address(t_endpointid, t_jobid, a_addressid);
            END IF;
        END IF;
    END;

    PROCEDURE createprimaryp12ifnewapp(a_relationshipid udt_id,
                                       a_asofdate      DATE,
                                       a_addressid     NUMBER DEFAULT NULL)
    IS
        t_primaryp12endpoint   udt_id
            := api.pkg_configquery.endpointidforname('j_Application',
                                                     'PrimaryP12Applicant');
        t_p12legalentity       udt_id;
        t_relexists            NUMBER;
        t_relid                udt_id;
        t_jobid                udt_id;
        t_endpointid           NUMBER
            := api.pkg_configquery.endpointidforname('j_Application',
                                                     'MailingAddress');
    BEGIN
        SELECT r.legalentityobjectid, r.applicationjobid
          INTO t_p12legalentity, t_jobid
          FROM query.r_applicationp12legalentity r
         WHERE r.relationshipid = a_relationshipid;

        SELECT COUNT(*)
          INTO t_relexists
          FROM api.relationships r
         WHERE r.fromobjectid = t_jobid
           AND r.endpointid = t_primaryp12endpoint
           AND ROWNUM = 1;

        IF t_relexists = 0 THEN
            t_relid   :=
                api.pkg_relationshipupdate.new(t_primaryp12endpoint,
                                               t_jobid,
                                               t_p12legalentity);

            IF a_addressid IS NOT NULL THEN
                propogatep12address(t_endpointid, t_jobid, a_addressid);
            END IF;
        END IF;
    END;

    PROCEDURE removep12app(a_jobid udt_id, a_asofdate DATE)
    IS
        t_p12legalentity   udt_id;
        t_p12relid         udt_id;
        t_prip12relid      udt_id;
        t_jobid            udt_id;
    BEGIN
        SELECT r.legalentityobjectid, r.applicationjobid, r.relationshipid
          INTO t_p12legalentity, t_jobid, t_p12relid
          FROM query.r_applicationp12legalentity r
         WHERE r.applicationjobid = a_jobid;

        SELECT r2.relationshipid
          INTO t_prip12relid
          FROM query.r_applicationprip12legalentity r2
         WHERE r2.applicationjobid = t_jobid
           AND r2.primaryp12leobjectid = t_p12legalentity;

        api.pkg_relationshipupdate.remove(t_p12relid);
        api.pkg_relationshipupdate.remove(t_prip12relid);
        api.pkg_columnupdate.setvalue(a_jobid, 'RemoveP12', '');
    END;

    PROCEDURE removep12lic(a_jobid udt_id, a_asofdate DATE)
    IS
        t_p12legalentity   udt_id;
        t_p12relid         udt_id;
        t_prip12relid      udt_id;
        t_jobid            udt_id;
    BEGIN
        SELECT r.legalentityobjectid, r.licensejobid, r.relationshipid
          INTO t_p12legalentity, t_jobid, t_p12relid
          FROM query.r_licensep12legalentity r
         WHERE r.licensejobid = a_jobid;

        SELECT r2.relationshipid
          INTO t_prip12relid
          FROM query.r_licenseprimaryp12legalentity r2
         WHERE r2.licensejobid = a_jobid
           AND r2.primayrp12leobjectid = t_p12legalentity;

        api.pkg_relationshipupdate.remove(t_p12relid);
        api.pkg_relationshipupdate.remove(t_prip12relid);
        api.pkg_columnupdate.setvalue(a_jobid, 'RemoveP12', '');
    END;

    PROCEDURE deleteprimaryp12app(a_jobid udt_id)
    IS
        t_primaryp12endpoint   udt_id
            := api.pkg_configquery.endpointidforname('j_Application',
                                                     'PrimaryP12Applicant');
        t_relid                udt_id;
        t_relcount             NUMBER;
        t_appextnum            VARCHAR2(30);
    BEGIN
        t_appextnum   :=
            api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum');

        SELECT COUNT(r.relationshipid)
          INTO t_relcount
          FROM query.r_applicationp12legalentity r
         WHERE r.applicationjobid = a_jobid;

        IF t_relcount = 1 THEN
            SELECT r.relationshipid
              INTO t_relid
              FROM api.relationships r
             WHERE r.fromobjectid = a_jobid
               AND r.endpointid = t_primaryp12endpoint;
        ELSIF t_relcount > 0 THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'P12 Legal Entity is currently the Primary Legal Entity on Application: '
                || t_appextnum);
        END IF;


        IF t_relid IS NOT NULL THEN
            api.pkg_relationshipupdate.remove(t_relid);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END deleteprimaryp12app;

    PROCEDURE deleteprimaryp12lic(a_jobid udt_id)
    IS
        t_primaryp12endpoint   udt_id
            := api.pkg_configquery.endpointidforname('j_Application',
                                                     'PrimaryP12Applicant');
        t_relid                udt_id;
        t_relcount             NUMBER;
        t_licextnum            VARCHAR2(30);
    BEGIN
        /*select r.LegalEntityObjectId, r.ApplicationJobId
         into t_P12LegalEntity, t_JobId
         from query.r_ApplicationP12LegalEntity r
        where r.RelationshipId = a_JobId;*/

        t_licextnum   :=
            api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum');

        SELECT COUNT(r.relationshipid)
          INTO t_relcount
          FROM query.r_licensep12legalentity r
         WHERE r.licensejobid = a_jobid;

        IF t_relcount = 1 THEN
            SELECT r.relationshipid
              INTO t_relid
              FROM api.relationships r
             WHERE r.fromobjectid = a_jobid
               AND r.endpointid = t_primaryp12endpoint;
        ELSIF t_relcount > 0 THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'P12 Legal Entity is currently the Primary Legal Entity on License: '
                || t_licextnum);
        END IF;


        IF t_relid IS NOT NULL THEN
            api.pkg_relationshipupdate.remove(t_relid);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END deleteprimaryp12lic;

    PROCEDURE propogatep12address(a_endpoint      NUMBER,
                                  a_jobid         NUMBER,
                                  a_addressid     NUMBER)
    IS
        t_oldmarel   NUMBER;
        t_relid      NUMBER;
    BEGIN
        SELECT MAX(r.relationshipid)
          INTO t_oldmarel
          FROM api.relationships r
         WHERE r.fromobjectid = a_jobid
           AND r.endpointid = a_endpoint;


        IF t_oldmarel IS NOT NULL THEN
            api.pkg_relationshipupdate.remove(t_oldmarel);
        END IF;

        t_relid   :=
            api.pkg_relationshipupdate.new(a_endpoint, a_jobid, a_addressid);
    END;

    PROCEDURE updatep12addresslic(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_licenseid               NUMBER;
        t_masterleobjid           NUMBER;
        t_masterlicobjid          NUMBER;
        t_oldmarel                NUMBER;
        t_addressid               NUMBER;

        t_relid                   NUMBER;
        t_endpointid              NUMBER
            := api.pkg_configquery.endpointidforname('j_License',
                                                     'MailingAddress');
        t_p12licenseeendpointid   NUMBER
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'PrimaryP12License');
    BEGIN
        pkg_debug.putline(
               '#####: Entering UpdateP12AddressLic. a_RelationshipId: '
            || a_relationshipid);

        SELECT lle.licensejobid, lle.primayrp12leobjectid
          INTO t_licenseid, t_masterleobjid
          FROM query.r_licenseprimaryp12legalentity lle
         WHERE lle.relationshipid = a_relationshipid;

        BEGIN
            SELECT r.toobjectid
              INTO t_masterlicobjid
              FROM api.relationships  r
                   JOIN
                   TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindex(
                               'j_License',
                               'ThisLicenseIsP12Master',
                               'Y') AS api.udt_objectlist)) ss
                       ON ss.objectid = r.toobjectid
             WHERE r.fromobjectid = t_masterleobjid
               AND r.endpointid = t_p12licenseeendpointid;

            SELECT r.maobjectid
              INTO t_addressid
              FROM query.r_licenseaddrmailing r
             WHERE r.licensejobid = t_masterlicobjid;


            SELECT MAX(r.relationshipid)
              INTO t_oldmarel
              FROM api.relationships r
             WHERE r.fromobjectid = t_licenseid
               AND r.endpointid = t_endpointid;

            IF t_oldmarel IS NOT NULL THEN
                api.pkg_relationshipupdate.remove(t_oldmarel);
            END IF;

            t_relid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_licenseid,
                                               t_addressid);
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('No Master License Found');
        END;
    END;
END pkg_p12;

/


GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_P12 TO KAURP;

GRANT EXECUTE ON SITESPECIFIC.PKG_P12 TO POSSEEXTENSIONS;

GRANT EXECUTE ON SITESPECIFIC.PKG_P12 TO TOOLBOX;
