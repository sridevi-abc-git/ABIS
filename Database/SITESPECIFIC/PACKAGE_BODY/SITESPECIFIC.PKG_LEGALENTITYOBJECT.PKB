CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_legalentityobject
IS
    -- **************************************************************************
    -- File:        PKG_LEGALENTITYOBJECT.PKB
    -- Author:      CX
    --
    -- $Rev: 432 $
    -- $Date: 2020-05-28 16:51:34 -0700 (Thu, 28 May 2020) $
    -- Last Changed By:  $Author: PKaur $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- 05/28/2020 PK          WO-21594 Adding Spouse reflecting under the wrong entity
    -- 05/08/2025 PK          Added foodlesseeApplication and License to FUNCTION rootconnectedtojob
    -- **************************************************************************
    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    gc_verifymangementdef      CONSTANT udt_id
        := api.pkg_configquery.objectdefidforname('o_LEVerifyManagement') ;

    gc_p12arootep              CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'P12ARoot') ;
    gc_lerootep                CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Root') ;
    gc_ledef                   CONSTANT udt_id
        := api.pkg_configquery.objectdefidforname('o_LegalEntity') ;
    gc_leparentstockholderep   CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'StockholderParentEntity') ;
    gc_lespouseep              CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Spouse2') ;
    gc_leofficerep             CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'OfficerParentEntity') ;
    gc_lep12aep                CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'P12AParent') ;


    TYPE udt_idbyid IS TABLE OF udt_id
        INDEX BY PLS_INTEGER;

    TYPE udt_idlistbyid IS TABLE OF udt_idlist
        INDEX BY PLS_INTEGER;

    TYPE udt_stringbyid IS TABLE OF VARCHAR2(4000)
        INDEX BY PLS_INTEGER;

    gc_processed                        udt_idbyid;
    gc_rootlegalentity                  udt_idbyid;

    g_processingqueue                   udt_idbyid;
    g_verifymanagementobject            udt_id;
    g_verifymanagementobjecttrans       udt_id;
    g_verifymanagementcounter           pls_integer := 0;


    g_sortcolumnbyid                    udt_stringbyid;

    CURSOR c_hierarchy(
        a_basesortkey   PLS_INTEGER,
        a_objectid      udt_id)
    IS
        SELECT
            NULL endpointid,
            a_objectid fromobjectid,
            NULL toobjectid,
            1 hierarchylevel,
            api.pkg_columnquery.VALUE(a_objectid, 'P12AStatus') p12astatus,
            (SELECT rootobjectid
              FROM query.r_p12alegalentityroot
             WHERE nodeobjectid = a_objectid) relatedp12aparent,
            (SELECT rootobjectid
               FROM query.r_legalentityroot
              WHERE nodeobjectid = a_objectid) relatedrootle,
           '/' || TO_CHAR(a_basesortkey, '099') || a_objectid sortkey
          FROM DUAL
        UNION ALL
            SELECT
                r.endpointid,
                r.fromobjectid,
                r.toobjectid,
                LEVEL + 1 hierarchylevel,
               api.pkg_columnquery.VALUE(r.fromobjectid, 'P12AStatus') p12astatus,
               (SELECT rootobjectid
                  FROM query.r_p12alegalentityroot
                 WHERE nodeobjectid = r.fromobjectid) relatedp12aparent,
               (SELECT rootobjectid
                  FROM query.r_legalentityroot
                 WHERE nodeobjectid = r.fromobjectid) relatedrootle,
                  '/' || TO_CHAR(a_basesortkey, '099') || a_objectid
                      || SYS_CONNECT_BY_PATH(
                          REPLACE(le.letreeviewtitle, '/', '')
                          --  || REPLACE(le.dup_formattedname, '/', ''),
                          || REPLACE(le.dup_formattedname || lpad(le.ObjectId, 9), '/', ''), '/') sortkey
                          --by PK WO-21594 Adding Spouse reflecting under the wrong entity

              FROM api.relationships r
                   JOIN api.objects f ON f.objectid = r.fromobjectid
                   JOIN query.o_legalentity le -- joining in the object allows for a single security hit,
                                               -- not one per api.pkg_ColumnQuery.Value
                                               ON le.objectid = r.fromobjectid
        START WITH r.toobjectid = a_objectid
               AND f.objectdefid = gc_ledef
               AND r.endpointid IN (gc_leparentstockholderep,
                                    gc_lespouseep,
                                    gc_leofficerep,
                                    gc_lep12aep)
        CONNECT BY r.toobjectid = PRIOR r.fromobjectid
               AND r.relationshipid != PRIOR r.relationshipid
               AND f.objectdefid = gc_ledef
               AND r.fromobjectid != a_objectid
               AND r.endpointid IN (gc_leparentstockholderep,
                                    gc_lespouseep,
                                    gc_leofficerep,
                                    gc_lep12aep)
        ORDER BY sortkey;

    CURSOR c_quickhierarchy(
        a_objectid      udt_id)
    IS
        SELECT NULL endpointid,
               a_objectid fromobjectid,
               (select LogicalTransactionId from api.Objects where objectid = a_ObjectId) FromObjLT,
               NULL toobjectid,
               Null ToObjLT,
               1 hierarchylevel,
               '/' || a_objectid sortkey
          FROM DUAL
        UNION ALL
            SELECT r.endpointid,
                   r.fromobjectid,
                   f.LogicalTransactionId FromObjLT,
                   r.toobjectid,
                   (select LogicalTransactionId from api.Objects where objectid = r.toobjectid) ToObjLT,
                   LEVEL + 1
                       hierarchylevel,
                   '/' || a_objectid || SYS_CONNECT_BY_PATH(r.fromobjectid, '/')
                       sortkey
              FROM api.relationships r
                   JOIN api.objects f ON f.objectid = r.fromobjectid
                   JOIN query.o_legalentity le -- joining in the object allows for a single security hit,
                                               -- not one per api.pkg_ColumnQuery.Value
                                               ON le.objectid = r.fromobjectid
        START WITH r.toobjectid = a_objectid
               AND f.objectdefid = gc_ledef
               AND r.endpointid IN (gc_leparentstockholderep,
                                    gc_lespouseep,
                                    gc_leofficerep,
                                    gc_lep12aep)
        CONNECT BY r.toobjectid = PRIOR r.fromobjectid
               AND r.relationshipid != PRIOR r.relationshipid
               AND f.objectdefid = gc_ledef
               AND r.fromobjectid != a_objectid
               AND r.endpointid IN (gc_leparentstockholderep,
                                    gc_lespouseep,
                                    gc_leofficerep,
                                    gc_lep12aep)
        ORDER BY sortkey;


    PROCEDURE dbg(msg VARCHAR2)
    IS
    BEGIN
        --NULL;
      pkg_Debug.PutSingleLine('pkg_LegalEntityObject: '||msg);

    END;


    PROCEDURE cacherootlegalentity(a_node udt_id, a_root udt_id)
    IS
    BEGIN
        dbg('Cache Root LE: ' || a_node || '=' || a_root);
        gc_rootlegalentity(a_node)   := a_root;
    END;

    FUNCTION rootlegalentity(a_objectid udt_id)
        RETURN udt_id
    IS
    BEGIN
       dbg('rootlegalentity, START, for: ' || a_objectid);

        IF NOT gc_rootlegalentity.EXISTS(a_objectid) THEN
            dbg('Get Root for: ' || a_objectid || ' CACHE MISS');
            cacherootlegalentity(
                a_objectid,
                pkg_legalentity.getrootlegalentity(a_objectid));
        ELSE
            dbg(
                   'Get Root for: '
                || a_objectid
                || ' CACHE HIT: '
                || gc_rootlegalentity(a_objectid));
        END IF;

       dbg('rootlegalentity, END, for: ' || a_objectid);
        RETURN gc_rootlegalentity(a_objectid);
    END;

    PROCEDURE postverifyprocedures(a_objectid udt_id, a_asofdate DATE)
    IS
        t_lestructurerel          VARCHAR2(150);
        t_ownertype               VARCHAR2(150);
        t_companyobjectid         udt_id;
        t_personobjectid          udt_id;
        t_percentageofownership   NUMBER;
    BEGIN
        dbg('Post Verify Procedures called for obj: ' || a_objectid);

        SELECT UPPER(lestructurerel),
               ownertype,
               percentageofownership,
               (SELECT rc.companyobjectid
                  FROM query.r_legalentitycompany rc
                 WHERE rc.legalentityobjectid = o.objectid)
                   companyobjectid,
               (SELECT rp.personobjectid
                  FROM query.r_legalentityperson rp
                 WHERE rp.legalentityobjectid = o.objectid)
                   personobjectid
          INTO t_lestructurerel,
               t_ownertype,
               t_percentageofownership,
               t_companyobjectid,
               t_personobjectid
          FROM query.o_legalentity o
         WHERE objectid = a_objectid;

        IF t_lestructurerel = 'STOCKHOLDER'
       AND t_ownertype IS NULL
       AND (t_companyobjectid IS NOT NULL
         OR t_personobjectid IS NOT NULL) THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'You must enter an Owner Type on '
                || 'each Stockholder Legal Entity.');
        END IF;

        IF t_lestructurerel = 'STOCKHOLDER'
       AND t_percentageofownership IS NULL
       AND (t_companyobjectid IS NOT NULL
         OR t_personobjectid IS NOT NULL) THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'You must enter a Percentage of '
                || 'Ownership on each Stockholder Legal Entity.');
        END IF;

        --Audit Logging on Object Verify
        extension.pkg_objectaudit.auditverify(
            a_objectid,
            a_asofdate,
            api.pkg_columnquery.VALUE(a_objectid, 'AuditColumns'),
            api.pkg_columnquery.VALUE(a_objectid, 'AuditRelationshipNames'),
            api.pkg_columnquery.VALUE(a_objectid, 'OmitPrefix'));

        --Maintain duplicate details (named 'dup_...')
        dbg('Post Verify Procedure, Maintain Duplicate Details called for: ' || a_objectid);
        toolbox.pkg_copy.maintainduplicatedetails(a_objectid, a_asofdate);

        --Run procedures - verify
        dbg('Post Verify Procedure, RunMaintain (Maintain P12A): ' || a_objectid);
        toolbox.pkg_procedure.runproceduresverify(
            a_objectid,
            a_asofdate,
            'RunMaintain<F>''Maintain P12A''');

        --Legal Entity Post Verify
        sitespecific.pkg_legalentity.lepostverify(a_objectid, a_asofdate);
        dbg('Post Verify Procedures END, for obj: ' || a_objectid);
    END;

    /*

    New "Post-verify hell" management technique that may be tried
    --Asusmption: verify procedures always run in order
    --Assumption: an objects verify cycle repeats until the object is stabilized
    If A,B,C,D,E,F are objects which have been created,
      A-F's post-verify
        - verifies existence of/creates a G-type object notes it in package-state
        - logs self in processing queue
      G's post-verify
        - deals with queue knowing the full set of objects to deal with

    How this helps ABIS:
      - POSSE may call verify's on dirty objects which will enqueue them in the G mechanism
      - G now may process the verify's on the objects actually made dirty
      - G may now calculate the hierarchy on the whole structure

    */

    PROCEDURE postverify(a_objectid udt_id, a_asofdate DATE)
    IS
        t_currentlogicaltransactionid   udt_id;
        t_hierarchybegin                PLS_INTEGER := NULL;
        t_jobrelationshipcount          PLS_INTEGER;
    BEGIN
        dbg('Post Verify called for ObjectId: ' || a_objectid);

        -- Only execute PostVerify on once per LogicalTransaction per ObjectId
        t_currentlogicaltransactionid   :=
            api.pkg_logicaltransactionupdate.currenttransaction();

        IF gc_processed.EXISTS(a_objectid)
       AND gc_processed(a_objectid) = t_currentlogicaltransactionid THEN
            dbg('Already processed Object: ' || a_objectid);
            RETURN;
        ELSE
            -- Create A Verify Management ObjectId if not alread created for this Session
            IF g_verifymanagementobject IS NULL THEN
                -- ISSUE030043 - new counter to allow a few loops, raise error after a number of loops
                if g_verifymanagementobjecttrans != t_currentlogicaltransactionid then
                    g_verifymanagementcounter := 0;
                    g_verifymanagementobjecttrans := t_currentlogicaltransactionid;
                elsif g_verifymanagementcounter > 100 then
                    raise_application_error(-20000, 'postverify on object '
                        || a_objectid || ' - one hundred verifymanagementobjects '
                        || 'already created in the same transaction, probable '
                        || ' infinite loop.');
                end if;
                g_verifymanagementcounter := g_verifymanagementcounter + 1;
                dbg(' Verify Management Object count: ' || g_verifymanagementcounter);

                g_verifymanagementobject   :=
                    api.pkg_objectupdate.new(gc_verifymangementdef);
            END IF;

            dbg('Adding to Processing Queue: ' || a_objectid);
            g_processingqueue(g_processingqueue.COUNT + 1)   := a_objectid;
            RETURN;
        END IF;
        dbg('Post Verify, END, for ObjectId: ' || a_objectid);
    END;

    FUNCTION calculatesortcolumn(a_objectid udt_id)
        RETURN VARCHAR2
    IS
        t_out              VARCHAR2(500);
        t_lestructurerel   VARCHAR2(15);
        t_sortkey          NUMBER(4);
        t_titletype        VARCHAR2(200);
        t_name             VARCHAR2(200);
    BEGIN
        SELECT    CASE
                      WHEN lestructurerel = 'On Sale Manager' THEN
                          'zz' || LPAD(NVL(sortkey, '9999'), 2, '0')
                      ELSE
                          LPAD(NVL(sortkey, '9999'), 2, '0')
                  END
               || SUBSTR(NVL(lestructurerel, '  '), 1, 2)
               || RPAD(NVL(titletype, ' '), 22, ' ')
               || RPAD(NVL(dup_formattedname, ' '), 50, ' ')
               || LPAD(objectid, 9, '0')
          INTO t_out
          FROM query.o_legalentity
         WHERE objectid = a_objectid;

        RETURN t_out;
    END;

    FUNCTION sortcolumnforid(a_objectid udt_id, a_parentobjectid udt_id)
        RETURN VARCHAR2
    IS
    BEGIN
        IF NOT g_sortcolumnbyid.EXISTS(a_objectid) THEN
            IF a_parentobjectid IS NOT NULL THEN
                g_sortcolumnbyid(a_objectid)   :=
                       g_sortcolumnbyid(a_parentobjectid)
                    || calculatesortcolumn(a_objectid);
            ELSE
                g_sortcolumnbyid(a_objectid)   :=
                    calculatesortcolumn(a_objectid);
            END IF;
        END IF;

        RETURN g_sortcolumnbyid(a_objectid);
    END;

    PROCEDURE droprelationship(a_objectid udt_id, a_endpointid udt_id)
    IS
    BEGIN
        dbg(
               'Delete Rel for EndPointId: '
            || a_endpointid
            || ' from: '
            || a_objectid);

        FOR i IN (SELECT relationshipid
                    FROM api.relationships
                   WHERE fromobjectid = a_objectid
                     AND endpointid = a_endpointid)
        LOOP
            api.pkg_relationshipupdate.remove(i.relationshipid);
        END LOOP;
    END;

    PROCEDURE createrelationship(a_objectid      udt_id,
                                 a_toobjectid    udt_id,
                                 a_endpointid    udt_id)
    IS
        t_relid   udt_id;
    BEGIN
        dbg(
               'Create Rel for EndPointId: '
            || a_endpointid
            || ' from: '
            || a_objectid
            || ' to: '
            || a_toobjectid);
        t_relid   :=
            api.pkg_relationshipupdate.new(a_endpointid,
                                           a_objectid,
                                           a_toobjectid);
    END;

    PROCEDURE maintainhierarchydata(a_objectid udt_id)
    IS
        t_ledef                udt_id;
        t_ep1                  udt_id;
        t_ep2                  udt_id;
        t_found                udt_id;
        t_p12aindex            PLS_INTEGER := 0;
        t_p12alevelmaster      udt_idlist;
        t_p12ahierarchystart   udt_idlist;
    BEGIN
        IF a_objectid != rootlegalentity(a_objectid) THEN
            dbg('Not Top Level Entity... exiting');
        END IF;

        dbg('Maintain Hierarchy for: ' || a_objectid);

        IF api.pkg_columnquery.VALUE(a_objectid, 'ShouldDelete') = 'Y' THEN
            dbg('Deleted LE ... exiting');
        END IF;

        --if the object does not exist any longer do not bother maintaining it's hierarchy.
        --Fix for ISSUE0034504
        SELECT COUNT(1)
          INTO t_found
          FROM api.objects
         WHERE objectid = a_objectid;

        IF t_found = 0 THEN
            RETURN;
        END IF;

        FOR i
            IN c_hierarchy(api.pkg_columnquery.VALUE(a_objectid, 'SortKey'),
                           a_objectid)
        LOOP
            /*      select count(*)
                    into t_Found
                    from api.Objects o
                   where o.ObjectId in (a_ObjectId, i.FromObjectId );
                   -- Do not process records if either object no longer exists in posse
                   -- Fix for P12 > LE Conversion
                   if t_Found < 2 then
                     CONTINUE;
                   end if;     */

            dbg(
                   'Level: '
                || i.hierarchylevel
                || ' :: From '
                || i.fromobjectid
                || ' up To '
                || i.toobjectid);

            /* the folowing P12A logic works because the SQL pulled above is
               ordered by the Sys_Connect_By_Path ensuring we're processing on
               branch at a time
            */
            IF i.p12astatus = 'Y' THEN
                -- P12AStatus flag is set on each P12A parent
                -- set markers to start creating rels from this P12A LE to children LEs

                IF t_p12aindex > 0
               AND t_p12alevelmaster(t_p12aindex) != i.fromobjectid THEN
                    -- capture scenario where P12As are siblings
                    -- in this case, simply switch the P12ALevelMaster and leave the indexing
                    -- and hierarchy indicator the same
                    dbg(
                           'Change P12A Master from '
                        || t_p12alevelmaster(t_p12aindex)
                        || ' to '
                        || i.fromobjectid);
                    t_p12alevelmaster(t_p12aindex)   := i.fromobjectid;
                    dbg('P12AIndex now:' || t_p12aindex);
                ELSE
                    dbg('Set P12A Master to: ' || i.fromobjectid);
                    t_p12aindex                         := t_p12aindex + 1;
                    t_p12alevelmaster(t_p12aindex)      := i.fromobjectid;
                    t_p12ahierarchystart(t_p12aindex)   := i.hierarchylevel;
                END IF;
            ELSIF t_p12aindex > 0
              AND i.hierarchylevel = t_p12ahierarchystart(t_p12aindex) THEN
                -- We're on a sibling LE to a P12A
                --turn OFF the markers triggering P12A rel creation
                dbg(
                       'Unset P12A: Master from: '
                    || t_p12alevelmaster(t_p12aindex));
                t_p12alevelmaster.delete(t_p12aindex);
                t_p12ahierarchystart.delete(t_p12aindex);
                t_p12aindex   := t_p12aindex - 1;
                dbg('P12AIndex now:' || t_p12aindex);
            END IF;

            IF t_p12aindex != 0 THEN
                IF i.relatedp12aparent IS NOT NULL THEN
                    IF i.relatedp12aparent != t_p12alevelmaster(t_p12aindex) THEN
                        -- drop existing rel first
                        droprelationship(i.fromobjectid, gc_p12arootep);
                        -- create a rel to P12A root
                        createrelationship(i.fromobjectid,
                                           t_p12alevelmaster(t_p12aindex),
                                           gc_p12arootep);
                    END IF;
                ELSE
                    -- no related P12A... create a rel to P12A root
                    createrelationship(i.fromobjectid,
                                       t_p12alevelmaster(t_p12aindex),
                                       gc_p12arootep);
                END IF;
            ELSE
                IF i.relatedp12aparent IS NOT NULL THEN
                    -- remove P12A rel
                    droprelationship(i.fromobjectid, gc_p12arootep);
                END IF;
            END IF;

            -- handle case where Root LE rel is missing
            IF i.relatedrootle IS NULL THEN
                SELECT COUNT(*)
                  INTO t_found
                  FROM api.relationships r
                 WHERE r.fromobjectid = i.fromobjectid
                   AND r.toobjectid = a_objectid
                   AND r.endpointid = gc_lerootep;

                -- Only create if not already created as a part of this cursor
                IF t_found = 0 THEN
                    createrelationship(i.fromobjectid,
                                       a_objectid,
                                       gc_lerootep);
                END IF;
            END IF;

            -- set Hierarchy Details
            api.pkg_columnupdate.setvalue(i.fromobjectid,
                                          'HierarchyLevel_Stored',
                                          i.hierarchylevel);
            api.pkg_columnupdate.setvalue(i.fromobjectid,
                                          'dup_HierarchyLevel',
                                          i.hierarchylevel);
            api.pkg_columnupdate.setvalue(i.fromobjectid,
                                          'SortColumn_Stored',
                                          i.sortkey);
        --SortColumnForId(i.FromObjectId, i.ToObjectId));
        END LOOP;
        dbg('Maintain Hierarchy, END, for Obj: ' || a_objectid);
    END;

    /* Shortcut to prevent Post-Verify from running on a given LegalEntity*/
    PROCEDURE markprocessed(a_objectid udt_id)
    IS
    BEGIN
        dbg('Marking ObjectId: ' || a_objectid || ' as processed');
        gc_processed(a_objectid)   :=
            api.pkg_logicaltransactionupdate.currenttransaction;
    END;

    FUNCTION rootconnectedtojob(a_objectid udt_id)
        RETURN BOOLEAN
    IS
        t_jobrelationshipcount   PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO t_jobrelationshipcount
          FROM api.relationships JOIN api.endpoints ep USING (endpointid)
         WHERE fromobjectid = a_objectid
           AND ep.name IN (                                    -- Applications
                           'AppApplication',
                           'ApplicationCopyApp',
                           'OSMApplication',
                           'FoodLesseeApplication',
                           'P12Application',
                           'PrimaryP12Application',
                           -- Licenses
                           'P12License',
                           'PrimaryP12License',
                           'LicenseCopy',
                           'LegalEntityLicense',
                           'FoodLesseeLicense',
                           'OSMLicense');

        RETURN t_jobrelationshipcount > 0;
    END;

    /***************************************************************************
     * The purpose of this Verify Management is to manage exactly what is
     * getting verified and when.
     * The Legal Entity Post-Verify event (per transaction) has created a new
     * one of the o_LEVerifyManagement objects and has loaded a package-state
     * variable with the list of objects that need to be verified.
     * This is the only way to know with certainty when all altered LE objects
     * have been registered (by means of their post-verify events loading their
     * ObjectIds into the variable).
     * Making use of the knowledge that POSSE always processed objects in
     * alphabetical order
     **************************************************************************/
    PROCEDURE verifymanagement(a_objectid udt_id, a_asofdate DATE)
    IS
        t_rootlegalentity               udt_idbyid;
        t_currentle                     udt_id;
        t_currentlogicaltransactionid   udt_id;
        t_objectid                      udt_id;
    BEGIN
        dbg('Executing LE Verify Management, START, ObjectId: ' || a_objectid);

        IF a_objectid != g_verifymanagementobject THEN
            dbg(
                   'Unexpected call to LE Verify Management from ObjectId: '
                || a_objectid
                || ' when ObjectId: '
                || g_verifymanagementobject
                || ' is in cache');
            raise_application_error(
                -20000,
                   'Unexpected call to LE Verify Management from ObjectId: '
                || a_objectid
                || ' when ObjectId: '
                || g_verifymanagementobject
                || ' is in cache');
        END IF;

        t_currentlogicaltransactionid   :=
            api.pkg_logicaltransactionupdate.currenttransaction;

        dbg(' current logicaltransation: ' || t_currentlogicaltransactionid);
        IF g_processingqueue.COUNT = 0 THEN
            RETURN;
        END IF;

        FOR i IN 1 .. g_processingqueue.COUNT
        LOOP
            dbg(
                   'Processing Queue member '
                || g_processingqueue(i)
                || ' with index '
                || i);
            -- if more than one root are in the queue... we handle it this way
            -- an array with the key/value = Root Id
            dbg('Add Root: '||RootLegalEntity(g_ProcessingQueue(i))||' to Root LE List');
            t_rootlegalentity(rootlegalentity(g_processingqueue(i)))   :=
                rootlegalentity(g_processingqueue(i));

            dbg('Run post verify procedures on g_processingqueue obj: '|| g_processingqueue(i));
            postverifyprocedures(g_processingqueue(i), a_asofdate);
        END LOOP;

        dbg(' Root LEs to be processed (count): '|| t_rootlegalentity.COUNT);
        t_currentle := t_rootlegalentity.FIRST;

        WHILE t_currentle IS NOT NULL
        LOOP
            dbg(' current LE '|| t_currentle);
            FOR j IN c_quickhierarchy(t_currentle)
            LOOP
                dbg(' Quick Heirarchy, FromObjectId: '|| j.fromobjectid);
                dbg(' a_ObjectId: '|| a_objectid);
                -- Mark all members of hierarchy as processed now so we can touch their sort data.
                -- To-objects are included to ensure that leaf nodes are also done.
                -- Doing both from- and to- objects is a lot of duplication but the
                -- extra overhead is small and doing it this way keeps the code simple.
                --IF j.fromobjectid < a_objectid THEN
				-- Compare LTs
				if (j.FromObjLT < t_currentlogicaltransactionid) or
				    (j.FromObjLT = t_currentlogicaltransactionid and j.FromObjectId < a_ObjectId) then
				-- Earlier transactions would have been processed already
				-- current transaction, only process objects with a larger objectid than the Verify Management Object
                    dbg(' FromObjectId is less than a_objectid');
                    dbg(' Update gc_processed, FromObjectId, to currentlogicaltransactionid');

                    gc_processed(j.fromobjectid) :=  t_currentlogicaltransactionid;
                    cacherootlegalentity(j.fromobjectid, t_currentle);
                END IF;
            END LOOP;

            maintainhierarchydata(t_currentle);
            t_currentle   := t_rootlegalentity.NEXT(t_currentle);
        END LOOP;

        for i in 1..g_processingqueue.count
        loop
           t_objectid := g_processingqueue(i);
           if not gc_processed.exists(t_objectid) or gc_processed(t_objectid) != t_currentlogicaltransactionid then
              dbg('Unprocessed legal entity ' || t_objectid || ' found. Possibly because it has been created and not yet added to a Legal Entity Structure.');
           end if;
        end loop;

        g_processingqueue.delete;
        g_verifymanagementobject := NULL;

        dbg('Executing LE Verify Management, END, for ObjectId: ' || a_objectid);
    END;

    PROCEDURE updatehierarchyonly(a_objectid udt_id)
    IS
        t_rootlegalentity               udt_id;
        t_currentlogicaltransactionid   udt_id;
    BEGIN
        t_rootlegalentity   := rootlegalentity(a_objectid);
        t_currentlogicaltransactionid   :=
            api.pkg_logicaltransactionupdate.currenttransaction;

        FOR j IN c_quickhierarchy(t_rootlegalentity)
        LOOP
            -- Mark all members of hierarchy as processed now so we can touch their sort data
            --IF j.fromobjectid < a_objectid THEN
            if (j.FromObjLT < t_currentlogicaltransactionid) or
				    (j.FromObjLT = t_currentlogicaltransactionid and j.FromObjectId < a_ObjectId) then
			  gc_processed(j.fromobjectid)   :=
                    t_currentlogicaltransactionid;
                cacherootlegalentity(j.fromobjectid, t_rootlegalentity);
            END IF;
        END LOOP;

        maintainhierarchydata(t_rootlegalentity);
    END;

    /*
     *  For a given node, replace existing root with the supplied one as the related root in cache
     */
    PROCEDURE replacerootrel(a_nodeobjectid udt_id, a_rootobjectid udt_id)
    IS
        t_relid   udt_id;
    BEGIN
        FOR i IN (SELECT relationshipid
                    FROM query.r_legalentityroot r
                   WHERE r.nodeobjectid = a_nodeobjectid)
        LOOP
            api.pkg_relationshipupdate.remove(i.relationshipid);
        END LOOP;

        createrelationship(a_nodeobjectid, a_rootobjectid, gc_lerootep);
        cacherootlegalentity(a_nodeobjectid, a_rootobjectid);
    END;
END pkg_legalentityobject;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_LEGALENTITYOBJECT TO POSSEEXTENSIONS;
