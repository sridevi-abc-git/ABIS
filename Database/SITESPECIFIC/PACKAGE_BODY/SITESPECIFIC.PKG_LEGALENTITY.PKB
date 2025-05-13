CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_legalentity
AS
    -- **************************************************************************
    -- File:        PKG_LEGALENTITY.PKB
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
    -- 05/08/2025 PK          Added to Food Lessee to procedure LegalEntityHierarchy
    -- 05/08/2025 PK          Added Food Lessee to PROCEDURE getappforle
    -- 05/08/2025 PK          Added Food Lessee to  PROCEDURE getlicforle
    -- 05/08/2025 PK          Added to Food Lessee to procedure LegalEntityHierarchy license
    -- 05/08/2025 PK          Added code for food lessee lic and app to  FUNCTION getlegalentityidforrel
    -- **************************************************************************

    gc_stockholderendpoint      udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'Stockholder');
    gc_officerendpoint          udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Officer');
    gc_leofficer                udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'OfficerParentEntity');
    gc_lespouse2                udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Spouse2');
    gc_lespouse1                udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Spouse1');
    gc_lestockholder            udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'StockholderParentEntity');
    gc_p12aparentendpoint       udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'P12AParent');
    gc_p12astockendpoint        udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'P12AStockholder');
    gc_licenseele               udt_id
        := api.pkg_configquery.endpointidforname('j_License',
                                                 'LicenseeLegalEntity');
    gc_applicantle              udt_id
        := api.pkg_configquery.endpointidforname('j_Application',
                                                 'Applicant');
    gc_licp12le                 udt_id
        := api.pkg_configquery.endpointidforname('j_License', 'P12Licensee');
    gc_p12le                    udt_id
        := api.pkg_configquery.endpointidforname('j_Application',
                                                 'P12Applicant');
    gc_licmanagerle             udt_id
        := api.pkg_configquery.endpointidforname('j_License',
                                                 'OSMLegalEntity');
    gc_managerle                udt_id
        := api.pkg_configquery.endpointidforname('j_Application',
                                                 'OnSaleManager');
    gc_foodlesseele                udt_id                                  -- Added by Pawan on 05/08/2025
        := api.pkg_configquery.endpointidforname('j_Application',
                                                 'FoodLesseeApp');
    gc_foodlesseelelic                udt_id                               -- Added by Pawan on 05/08/2025
        := api.pkg_configquery.endpointidforname('j_License',
                                                 'FoodLesseeLic');
    gc_lelicensee               udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'LegalEntityLicense');
    gc_lep12licensee            udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'PrimaryP12License');
    gc_leosmlicensee            udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'OSMLicense');
    gc_officerep       CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Officer') ;
    gc_spouse1ep       CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Spouse1') ;
    gc_stockholderep   CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                 'Stockholder') ;

    gc_rootep          CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Root') ;
    gc_p12arootep      CONSTANT udt_id
        := api.pkg_configquery.endpointidforname('o_LegalEntity', 'P12ARoot') ;

    TYPE relobjscreated IS TABLE OF NUMBER
        INDEX BY VARCHAR2(4000);

    gc_relobjscreated           relobjscreated;

    /*---------------------------------------------------------------------------
    * GetLegalEntityHierarchy() -- PUBLIC
    * Modified by: Andy Patterson  Magill (CXUSA)
    * Modified on: 10/28/2015
    * We added the two lines in the CONNECT BY clause that prevent this code from
    * looping back up to the top-level Legal Entity object. Also, don't copy the
    * temporary OfficerStockholder relationship that is used for copying data.
    *-------------------------------------------------------------------------*/
    FUNCTION getlegalentityhierarchy(a_objectid udt_id)
        RETURN udt_legalentityrel
    IS
        t_legalentities   udt_legalentityrel;
        t_objectdefid     udt_id;
        t_tempshoffepid   udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'OfficerStockholder');
        t_parentleepid    udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'ParentEntity');
        t_rootleepid      udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Root');
        t_officerparent   udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'OfficerParentEntity');
        t_p12aroot        udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'P12ARoot');
        t_p12aparent      udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'P12AParent');
        t_nodeep          udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity', 'Node');
    BEGIN
        t_objectdefid   :=
            api.pkg_configquery.objectdefidforname('o_LegalEntity');

        OPEN t_legalentities FOR
                SELECT DISTINCT r.endpointid,
                                r.fromobjectid,
                                r.toobjectid,
                                LEVEL nestlevel
                  FROM api.relationships r
                       JOIN api.objects f ON f.objectid = r.fromobjectid
            START WITH r.toobjectid = a_objectid
                   AND f.objectdefid = t_objectdefid
                   AND r.endpointid NOT IN (t_tempshoffepid,
                                            t_parentleepid,
                                            t_rootleepid,
                                            t_officerparent,
                                            t_p12aroot,
                                            t_p12aparent)
            CONNECT BY NOCYCLE r.toobjectid = PRIOR r.fromobjectid
                           AND f.objectdefid = t_objectdefid
                           --Don't go back up to the top of the Legal Entity Structure
                           AND r.fromobjectid != a_objectid
                           --Exclude the Officer/Stockholder temp rels that aren't being deleted
                           --Also ignore the ParentLegalEntity endpoint so we don't walk back up the hierarchy. "I'm my own grandpa!"
                           AND r.endpointid NOT IN (t_tempshoffepid,
                                                    t_parentleepid,
                                                    t_rootleepid,
                                                    t_p12aroot,
                                                    t_nodeep)
              ORDER BY LEVEL, r.toobjectid, r.fromobjectid;

        RETURN t_legalentities;
    END getlegalentityhierarchy;

    /*---------------------------------------------------------------------------
    * GetLegalEntityChildren() -- PUBLIC
    *-------------------------------------------------------------------------*/
    FUNCTION getlegalentitychildren(a_objectid udt_id)
        RETURN udt_legalentityrel
    IS
        t_legalentities   udt_legalentityrel;
        t_objectdefid     udt_id;
    BEGIN
        t_objectdefid   :=
            api.pkg_configquery.objectdefidforname('o_LegalEntity');

        OPEN t_legalentities FOR
                SELECT api.pkg_configquery.otherendpointidforname(
                           'o_LegalEntity',
                           (SELECT ep.name
                              FROM api.endpoints ep
                             WHERE ep.endpointid =
                                   r.endpointid))
                           endpointid,
                       r.toobjectid,
                       r.fromobjectid,
                       LEVEL
                           nestlevel           --Do to and from need to switch
                  FROM api.relationships r
                       JOIN api.objects f ON f.objectid = r.toobjectid
            START WITH r.fromobjectid = a_objectid
                   AND f.objectdefid = t_objectdefid
                   AND r.endpointid IN (gc_officerendpoint,
                                        gc_lespouse1,
                                        gc_stockholderendpoint,
                                        gc_p12astockendpoint)
            CONNECT BY r.fromobjectid = PRIOR r.toobjectid
                   AND r.relationshipid != PRIOR r.relationshipid
                   AND f.objectdefid = t_objectdefid
                   AND r.endpointid IN (gc_officerendpoint,
                                        gc_lespouse1,
                                        gc_stockholderendpoint,
                                        gc_p12astockendpoint)
              ORDER BY LEVEL, r.toobjectid, r.fromobjectid;

        RETURN t_legalentities;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN t_legalentities;
    END;

  /*---------------------------------------------------------------------------
  * GetJobLEChildren() -- PUBLIC
  * Get Legal Entities for the Application or License Job
  *-------------------------------------------------------------------------*/
  function GetJobLEChildren(a_ObjectId udt_Id)
           return api.pkg_definition.udt_IdList is
    
  t_ObjectDefId   udt_Id := api.pkg_ConfigQuery.ObjectDefIdForName('o_LegalEntity');
  t_OfficerEP               number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'OfficerStockholder');
  t_ParentEP                number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'ParentEntity');
  t_RootEP                  number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'Root'); 
  t_OffParentEP             number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'OfficerParentEntity');
  t_p12aRootEP              number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'P12ARoot');
  t_p12aParent              number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'P12AParent');
  t_NodeEP                  number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'Node') ;    
  t_JobLegalEntities api.pkg_definition.udt_IdList;
  begin

    select distinct  r.FromObjectId
    bulk collect into t_JobLegalEntities
      from api.Relationships r
      join api.Objects f on f.ObjectId = r.FromObjectId
       start with r.ToObjectId = a_ObjectId
          and f.ObjectDefId = t_ObjectDefId
          and r.EndPointId not in ( 
                      t_OfficerEP,
                      t_ParentEP,
                      t_RootEP, 
                      t_OffParentEP,
                      t_p12aRootEP,
                      t_p12aParent
                      )
      connect by NOCYCLE r.ToObjectId = prior r.FromObjectId
         and f.ObjectDefId = t_ObjectDefId
         and r.FromObjectId != a_ObjectId    
         and r.EndPointId not in (
                      t_OfficerEP,
                      t_ParentEP,
                      t_RootEP, 
                      t_p12aRootEP , 
                      t_NodeEP 
                      );

    return t_JobLegalEntities;

    exception when no_data_found then
     return t_JobLegalEntities;

  end GetJobLEChildren;

    /*---------------------------------------------------------------------------
    * LegalEntityChildren() -- PRIVATE
    *-------------------------------------------------------------------------*/
    PROCEDURE getlegalentitychildren(
        a_objectid            udt_id,
        a_relatedobjectids IN OUT api.udt_objectlist)
    IS
    /*t_LegalEntities udt_LegalEntityRel;
    t_ChildObjectId udt_Id;*/
    BEGIN
        FOR c IN (SELECT r.fromobjectid
                    FROM api.relationships r
                   WHERE r.endpointid IN (gc_leofficer,
                                          gc_lespouse2,
                                          gc_lestockholder,
                                          gc_p12aparentendpoint)
                     AND r.toobjectid = a_objectid)
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.fromobjectid);
            getlegalentitychildren(c.fromobjectid, a_relatedobjectids);
        END LOOP;
    END;


    /*---------------------------------------------------------------------------
    * GetLegalEntityChildrenNew() -- PUBLIC
    * Cloned from GetLegalEntityChildren to prevent a connect by loop that
    * was happenning when connecting highly complicated hierarchies.
    * Added in checking to filter out the original object so the original object
    * would not show up as a grandchild entity
    * Created by: Daniel Magill
    * Created Date: 10/22/15
    *-------------------------------------------------------------------------*/
    FUNCTION getlegalentitychildrennew(a_objectid udt_id)
        RETURN udt_legalentityrel
    IS
        t_legalentities   udt_legalentityrel;
        t_objectdefid     udt_id;
    BEGIN
        t_objectdefid   :=
            api.pkg_configquery.objectdefidforname('o_LegalEntity');

        OPEN t_legalentities FOR
                SELECT r.endpointid,
                       r.fromobjectid,
                       r.toobjectid,
                       LEVEL nestlevel
                  FROM api.relationships r
                       JOIN api.objects o ON o.objectid = r.toobjectid
                       JOIN api.endpoints e ON e.endpointid = r.endpointid
            START WITH r.fromobjectid = a_objectid
                   AND o.objectdefid = t_objectdefid
                   AND r.endpointid IN
                           (gc_officerendpoint,
                            gc_lespouse1,
                            gc_stockholderendpoint)
            CONNECT BY NOCYCLE -- Eliminates the cycle in user database that was being caused in the user data
                               r.fromobjectid = PRIOR r.toobjectid
                           AND r.relationshipid != PRIOR r.relationshipid
                           AND o.objectdefid = t_objectdefid
                           AND r.endpointid IN
                                   (gc_officerendpoint,
                                    gc_lespouse1,
                                    gc_stockholderendpoint);

        RETURN t_legalentities;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN t_legalentities;
    END;

    /*---------------------------------------------------------------------------
    * LegalEntityHierarchy() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE legalentityhierarchy(a_objectid         udt_id,
                                   a_endpointid       udt_id,
                                   a_relatedobjectids OUT api.udt_objectlist)
    IS
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c IN (SELECT r.toobjectid
                    FROM api.relationships r
                   WHERE r.endpointid IN (gc_licenseele,
                                          gc_applicantle,
                                          gc_p12le,
                                          gc_managerle,
                                          gc_foodlesseele,
                                          gc_foodlesseelelic,
                                          gc_licp12le,
                                          gc_licmanagerle)
                     AND r.fromobjectid = a_objectid)
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.toobjectid);
            getlegalentitychildren(c.toobjectid, a_relatedobjectids);
        END LOOP;
    END;

    /*---------------------------------------------------------------------------
    * LegalEntityHierarchyFirstLvl() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE legalentityhierarchyfirstlvl(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_lethreshhold   NUMBER
            := api.pkg_constantquery.VALUE('LegalEntityLiteThreshold');
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c
            IN (  SELECT r.toobjectid,
                         api.pkg_columnquery.numericvalue(
                             r.toobjectid,
                             'HierarchyLevel_Stored')
                             hierarchy
                    FROM api.relationships r
                   WHERE r.endpointid IN (gc_licenseele,
                                          gc_applicantle,
                                          gc_p12le,
                                          gc_managerle,
                                          gc_foodlesseele,
                                          gc_foodlesseelelic,
                                          gc_licp12le,
                                          gc_licmanagerle)
                     AND r.fromobjectid = a_objectid
                ORDER BY 2)
        LOOP
            --Only return the rows where the hierarchy level is 1.
            IF c.hierarchy = 1 THEN
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                    api.udt_object(c.toobjectid);
            /*        if t_LEThreshhold = a_RelatedObjectIds.Count then
                      -- exit the loop and stop looking for more
                      exit;*/
            END IF;
        END LOOP;
    END;

    /*---------------------------------------------------------------------------
    * ApplicationforLegalEntity() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE applicationforlegalentity(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist)
    IS
        /*t_LegalEntities udt_LegalEntityRel;*/
        t_applicationid   NUMBER;
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        --api.pkg_errors.raiseerror(-20000, a_ObjectId);

        BEGIN
            SELECT jobid
              INTO t_applicationid
              FROM api.jobs
             WHERE externalfilenum =
                   api.pkg_columnquery.VALUE(a_objectid, 'RelatedJobFileNo');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN;
        END;

        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT)   :=
            api.udt_object(t_applicationid);
    END;

    --*------------------------------------------------------------------------------------------------
    --* GetLEParent() -- Public
    --* Return the Parent of Legal Entity
    --*------------------------------------------------------------------------------------------------
    FUNCTION getleparent(a_objectid udt_id)
        RETURN udt_id
    IS
        t_leparentobjectid   udt_id;
    BEGIN
        BEGIN
            t_leparentobjectid   :=
                api.pkg_columnquery.VALUE(a_objectid, 'ParentObjectId');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL;
        END;

        RETURN t_leparentobjectid;
    END getleparent;

    /*
      Access to Root Legal Entity
    */
    FUNCTION getrootlegalentity(a_objectid udt_id)
        RETURN udt_id
    IS
        t_topparentleobjectid   udt_id;
        t_leobjectid            udt_id;
    BEGIN
        SELECT DISTINCT rootobjectid
          INTO t_topparentleobjectid
          FROM query.r_legalentityroot
         WHERE nodeobjectid = a_objectid;

        RETURN t_topparentleobjectid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            t_leobjectid            := a_objectid;
            t_topparentleobjectid   := NULL;

            WHILE t_leobjectid IS NOT NULL
            LOOP
                t_topparentleobjectid   := t_leobjectid;

                SELECT NVL(
                           (SELECT spouse2objectid
                              FROM query.r_legalentityspouse
                             WHERE spouse1objectid = t_leobjectid),
                           NVL(
                               (SELECT parententityobjectid
                                  FROM query.r_officergenpartnerprincipal
                                 WHERE officerobjectid = t_leobjectid),
                               NVL(
                                   (SELECT parententityobjectid
                                      FROM query.r_stockholderlimitedpartner
                                     WHERE stockholderobjectid = t_leobjectid),
                                   NVL(
                                       (SELECT p12aparentobjectid
                                          FROM query.r_p12astockholderparent
                                         WHERE p12astockholderobjectid =
                                               t_leobjectid),
                                       NULL))))
                  INTO t_leobjectid
                  FROM DUAL;
            END LOOP;

            RETURN t_topparentleobjectid;
    END;

    --*------------------------------------------------------------------------------------------------
    --* GetTopMostLEParent() -- Public
    --* Return the Top Most Parent of Legal Entity
    --*------------------------------------------------------------------------------------------------
    FUNCTION gettopmostleparent(a_objectid udt_id)
        RETURN udt_id
    IS
        t_leobjectid            udt_id;
        t_topparentleobjectid   udt_id;
    BEGIN
        t_leobjectid            := a_objectid;
        t_topparentleobjectid   := NULL;

        WHILE t_leobjectid IS NOT NULL
        LOOP
            t_topparentleobjectid   := t_leobjectid;

            SELECT NVL(
                       (SELECT spouse2objectid
                          FROM query.r_legalentityspouse
                         WHERE spouse1objectid = t_leobjectid),
                       NVL(
                           (SELECT parententityobjectid
                              FROM query.r_officergenpartnerprincipal
                             WHERE officerobjectid = t_leobjectid),
                           NVL(
                               (SELECT parententityobjectid
                                  FROM query.r_stockholderlimitedpartner
                                 WHERE stockholderobjectid = t_leobjectid),
                               NVL(
                                   (SELECT p12aparentobjectid
                                      FROM query.r_p12astockholderparent
                                     WHERE p12astockholderobjectid =
                                           t_leobjectid),
                                   NULL))))
              INTO t_leobjectid
              FROM DUAL;
        END LOOP;

        RETURN t_topparentleobjectid;
    END gettopmostleparent;

    --*------------------------------------------------------------------------------------------------
    --* GetAppForLE() -- PUBLIC
    --* Find the application with which the legal entity is assocated.  This returns no Applications related to an LE as P12s.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getappforle(a_objectid         udt_id,
                          a_endpointid       udt_id,
                          a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_applicantendpointid               udt_id;
        t_osmapplicantendpointid            udt_id;
        t_topparentleobjectid               udt_id;
        t_foodlesseeapplicantendpointid     udt_id;
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();
        t_applicantendpointid   :=
            api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                  'AppApplication');
        t_osmapplicantendpointid   :=
            api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                  'OSMApplication');
                                                  
        t_foodlesseeapplicantendpointid   :=
            api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                  'FoodLesseeApplication');

        FOR c
            IN (SELECT r.toobjectid
                  FROM api.relationships  r
                       JOIN query.r_legalentityroot r2
                           ON r2.rootobjectid = r.fromobjectid
                 WHERE r2.nodeobjectid = a_objectid
                   AND r.endpointid IN
                           (t_applicantendpointid, t_osmapplicantendpointid,  t_foodlesseeapplicantendpointid))
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.toobjectid);
        END LOOP;
    END getappforle;

    --*------------------------------------------------------------------------------------------------
    --* GetLicForLE() -- PUBLIC
    --* Find the license with which the legal entity is assocated.  In the case of P12, this returns the P12 Master.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getlicforle(a_objectid         udt_id,
                          a_endpointid       udt_id,
                          a_relatedobjectids OUT api.udt_objectlist)
    IS
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c
            IN (SELECT r.toobjectid
                  FROM query.r_legalentityroot  r2
                       JOIN api.relationships r
                           ON r2.rootobjectid = r.fromobjectid
                 WHERE r2.nodeobjectid = a_objectid
                   AND r.endpointid IN (gc_lelicensee, gc_leosmlicensee, gc_foodlesseelelic)
                UNION ALL
                SELECT r.toobjectid
                  FROM query.r_legalentityroot  r2
                       JOIN api.relationships r
                           ON r2.rootobjectid = r.fromobjectid
                       JOIN query.r_p12license r3
                           ON r3.p12license1objectid = r.toobjectid
                 WHERE r2.nodeobjectid = a_objectid
                   AND r.endpointid = gc_lep12licensee--and exists (select 1 from query.r_p12license tr where tr.P12License1ObjectId = r.ToObjectId)
                                                      )
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.toobjectid);
        END LOOP;
    END getlicforle;

    --------------------------------------------------------------------------------------
    --  LegalEntityCopy() -- PUBLIC
    --Copies the reference Legal Entity
    --Copies all legal entities associated with the reference Legal Entity,
    --  and their descendant legal entities.
    --Creates relationships between the newly created parent/child legal entities
    --Creates relationships between existing person, child, title object
    --  and the appropriate newly created legal entity.
    --Copies ALL stored details of Stockholder legal entity onto
    --  the copy of the stockholder legal entity
    --  (the point is to copy stockholder details Owner Type and Percentage of Ownership)
    --------------------------------------------------------------------------------------

    FUNCTION legalentitycopy(a_objectid      udt_id,
                             a_isp12acopy    BOOLEAN DEFAULT FALSE,
                             a_maintain      BOOLEAN DEFAULT FALSE)
        RETURN udt_id
    IS
        t_p12amasterlicense   udt_id;
        t_p12amasterleidold   udt_id;
        t_legalentityobjid    udt_id;
        t_p12aarray           udt_p12alist;
    BEGIN
        t_legalentityobjid   :=
            legalentitycopy(a_objectid,
                            t_p12amasterlicense,
                            t_p12amasterleidold,
                            t_p12aarray,
                            a_isp12acopy,
                            a_maintain);
        RETURN t_legalentityobjid;
    END legalentitycopy;

    FUNCTION legalentitycopy(a_objectid            udt_id,
                             a_p12amasterlicense   OUT NUMBER,
                             a_p12amasterleidold   OUT NUMBER,
                             a_p12aarray    IN OUT udt_p12alist,
                             a_isp12acopy          BOOLEAN DEFAULT FALSE,
                             a_maintain            BOOLEAN DEFAULT FALSE)
        RETURN udt_id
    IS
        t_legalentities      udt_legalentityrel;

        TYPE lelisttype IS TABLE OF NUMBER
            INDEX BY PLS_INTEGER;                         -- Associative Array

        legalentityxref      lelisttype;

        t_compreldefid       udt_id;
        t_endpointids        udt_idlist;
        t_fromobjdefid       udt_id;
        t_fromobjectids      udt_idlist;
        t_legalentitydefid   udt_id;
        t_lesortkey          NUMBER;
        t_exists             NUMBER;
        x                    udt_id;
        t_levels             udt_idlist;
        t_newfromobjectid    udt_id;
        t_newrelobjectid     udt_id;
        t_newtoobjectid      udt_id;
        t_p12areldefid       udt_id;
        t_perreldefid        udt_id;
        t_reldefid           udt_id;
        t_spousereldefid     udt_id;
        t_stkreldefid        udt_id;
        t_titlereldefid      udt_id;
        t_toobjectids        udt_idlist;
        t_masterleobjectid   udt_id;
        t_newmasterleid      udt_id;
        t_p12aarray          udt_p12alist;
        t_name               VARCHAR2(2000);
        t_epname             VARCHAR2(2000);
        t_epname2            VARCHAR2(2000);
        t_objectdefname      VARCHAR2(2000);
        t_fromobjectname     VARCHAR2(2000);
        t_toobjectname       VARCHAR2(2000);
    BEGIN
        -- put into REF CURSOR information about the LE and all LEs directly related to it.
        IF a_isp12acopy THEN
            t_legalentities   := getlegalentitychildren(a_objectid);
        ELSE
            t_legalentities   := getlegalentityhierarchy(a_objectid);
        END IF;

        t_stkreldefid                 :=
            api.pkg_configquery.objectdefidforname(
                'r_StockholderLimitedPartner');
        t_p12areldefid                :=
            api.pkg_configquery.objectdefidforname('r_P12AStockholderParent');
        t_perreldefid                 :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityPerson');
        t_compreldefid                :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityCompany');
        t_titlereldefid               :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityTitle');
        t_legalentitydefid            :=
            api.pkg_configquery.objectdefidforname('o_LegalEntity');
        t_spousereldefid              :=
            api.pkg_configquery.objectdefidforname('r_LegalEntitySpouse');

        -- CLONE THE LEGAL ENTITY PASSED IN.
        t_newtoobjectid               := api.pkg_objectupdate.new(t_legalentitydefid);
        -- store the new LE object in the array, referenced by the existing Master LE object
        legalentityxref(a_objectid)   := t_newtoobjectid;

        -- 04.07.2008 SortKey detail. Copy from source LE Object to new LE.
        BEGIN
            SELECT le.sortkey
              INTO t_lesortkey
              FROM query.o_legalentity le
             WHERE le.objectid = a_objectid;

            api.pkg_columnupdate.setvalue(legalentityxref(a_objectid),
                                          'SortKey',
                                          t_lesortkey);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;     -- The SetValue field does not have be to populated.
        END;

        --   Find and copy all existing relationships for t_ToObjectId Legal Entity to Person, Company, Title.
        --   Relationships for Officer, Stockholder and Spouse Legal Entities dealt with separately
        t_p12aarray                   := udt_p12alist();

        FOR c
            IN (SELECT rel.relationshipdefid,
                       rel.fromobjectid,
                       rel.endpointid
                  FROM api.relationships rel
                 WHERE rel.toobjectid = a_objectid
                   AND rel.relationshipdefid IN
                           (t_perreldefid, t_compreldefid, t_titlereldefid))
        LOOP
            t_newrelobjectid   :=
                api.pkg_relationshipupdate.new(c.endpointid,
                                               c.fromobjectid,
                                               legalentityxref(a_objectid));
        END LOOP;

        FETCH t_legalentities
            BULK COLLECT INTO t_endpointids,
                 t_fromobjectids,
                 t_toobjectids,
                 t_levels;

        FOR i IN 1 .. t_endpointids.COUNT
        LOOP
            -- start evaluation of the t_FromObjectId.
            SELECT obj2.objectdefid, od2.name
              INTO t_fromobjdefid, t_objectdefname
              FROM api.objects  obj2
                   JOIN api.objectdefs od2
                       ON od2.objectdefid = obj2.objectdefid
             WHERE obj2.objectid = t_fromobjectids(i);

            --
            IF t_fromobjectids(i) = t_toobjectids(i) THEN
                CONTINUE;
            END IF;

            --The SQL from GetLegalEntityHierarchy sometimes returns things twice
            --This Ensures that duplicates do not create extra LE 
            t_exists                              := 0;
            x                                     := legalentityxref.FIRST;

            WHILE x IS NOT NULL
              AND t_exists = 0
            LOOP
                IF x = t_fromobjectids(i) THEN
                    t_exists   := 1;
                END IF;

                x   := legalentityxref.NEXT(x);
            END LOOP;

            IF t_exists > 0 THEN
                CONTINUE;
            END IF;

            t_newfromobjectid                     := api.pkg_objectupdate.new(t_fromobjdefid);
            legalentityxref(t_fromobjectids(i))   := t_newfromobjectid;

            IF NOT a_isp12acopy THEN
                -- Create a Stored rel directly to the Root of the structure
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(gc_rootep,
                                                   t_newfromobjectid,
                                                   t_newtoobjectid);
            END IF;

            --Copy all stored dynamic details from existing Stockholder Legal Entity to
            --  new Stockholder Legal Entity
            SELECT rel.relationshipdefid
              INTO t_reldefid
              FROM api.relationshipdefs rel
             WHERE rel.toendpointid = t_endpointids(i);

            IF t_reldefid IN (t_stkreldefid, t_p12areldefid) THEN
                -- SG: Added FromObjectId exclusion to fix the Root Legal Entity from being overwritten
                -- by the FromObjectId from the source legal entity used to copy these details from.
                pkg_copy.copystoredobjdetailsexception(
                    t_fromobjectids(i),
                    legalentityxref(t_fromobjectids(i)),
                    'HierarchyLevel_Stored,FromObjectId');
                -- SG: Added to fix case where entire heirarchy is cloned Eg: Issuing License
                -- And the source objectid has a different root than the current heirarchy.
                api.pkg_columnupdate.setvalue(t_newtoobjectid,
                                              'FromObjectId',
                                              t_newfromobjectid);
            END IF;

            t_masterleobjectid                    :=
                api.pkg_columnquery.VALUE(t_fromobjectids(i),
                                          'P12AMasterLEId');

            IF t_masterleobjectid IS NOT NULL THEN
                INSERT INTO p12alog_t t
                     VALUES (t_newfromobjectid, t_masterleobjectid);

                DELETE FROM p12alog_t t2
                      WHERE t2.leobjectid = t_fromobjectids(i);

                IF a_p12amasterleidold IS NULL
                OR a_p12amasterleidold != t_masterleobjectid THEN
                    t_p12aarray.EXTEND;
                    a_p12amasterlicense   :=
                        api.pkg_columnquery.VALUE(t_newfromobjectid,
                                                  'P12AMasterLicenseJobId');
                    a_p12amasterleidold   := t_masterleobjectid;
                    t_p12aarray(t_p12aarray.COUNT)   :=
                        udt_p12arecord(t_masterleobjectid,
                                       a_p12amasterlicense);
                END IF;
            END IF;

            --   Find all existing relationships for t_FromObjectId Legal Entity
            --   Relate to existing company, person, title objects
            FOR c2
                IN (SELECT rel2.relationshipdefid,
                           rel2.fromobjectid,
                           rel2.endpointid
                      FROM api.relationships rel2
                     WHERE rel2.toobjectid = t_fromobjectids(i)
                       AND rel2.relationshipdefid IN
                               (t_perreldefid,
                                t_compreldefid,
                                t_titlereldefid))
            LOOP
                -- Only create relationship; don't create a new object for person, company, title
                t_newrelobjectid   :=
                    api.pkg_relationshipupdate.new(
                        c2.endpointid,
                        c2.fromobjectid,
                        legalentityxref(t_fromobjectids(i)));
            END LOOP;

            -- end evaluation of the t_FromObjectId.
            -- Relate the two newly created Legal Entities.
            t_newrelobjectid                      :=
                api.pkg_relationshipupdate.new(
                    t_endpointids(i),
                    legalentityxref(t_fromobjectids(i)),
                    legalentityxref(t_toobjectids(i)));
        END LOOP;

        CLOSE t_legalentities;

        a_p12aarray                   := t_p12aarray;

        -- Return the new master Legal Entity master object id
        RETURN legalentityxref(a_objectid);
    END legalentitycopy;

    PROCEDURE legalentitylookupcopy(a_relationshipid udt_id,
                                    a_asofdate      DATE,
                                    a_relationshipdefname VARCHAR2,
                                    a_endpointname  VARCHAR2)
    IS
        t_p12amasterlicense   NUMBER;
        t_p12amasterleidold   NUMBER;
        t_p12aarrary          udt_p12alist;
    BEGIN
        legalentitylookupcopy(a_relationshipid,
                              a_asofdate,
                              t_p12amasterlicense,
                              t_p12amasterleidold,
                              t_p12aarrary,
                              a_relationshipdefname,
                              a_endpointname);
    END legalentitylookupcopy;

    /*---------------------------------------------------------------------------
    * LegalEntityLookupCopy() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE legalentitylookupcopy(a_relationshipid      udt_id,
                                    a_asofdate            DATE,
                                    a_p12amasterlicense   OUT NUMBER,
                                    a_p12amasterleidold   OUT NUMBER,
                                    a_p12aarray    IN OUT udt_p12alist,
                                    a_relationshipdefname VARCHAR2,
                                    a_endpointname        VARCHAR2)
    IS
        t_targetlegalentityid   udt_id;
        t_newlegalentityid      udt_id;
        t_endpointid            udt_id;
        t_fromobjectid          udt_id;
        t_relationshipid        udt_id;
        t_oldparentobjid        udt_id;
        t_remrelationshipid     udt_id;
    BEGIN
        SELECT r.toobjectid, r.fromobjectid
          INTO t_targetlegalentityid, t_fromobjectid
          FROM api.relationships  r
               JOIN api.objects o ON o.objectid = r.toobjectid
         WHERE r.relationshipid = a_relationshipid
           AND o.objectdefid =
               api.pkg_configquery.objectdefidforname('o_LegalEntity');

        t_newlegalentityid   :=
            legalentitycopy(t_targetlegalentityid,
                            a_p12amasterlicense,
                            a_p12amasterleidold,
                            a_p12aarray);
        t_endpointid   :=
            NVL(
                api.pkg_configquery.endpointidforname('j_Application',
                                                      a_endpointname),
                api.pkg_configquery.endpointidforname('j_License',
                                                      a_endpointname));

        t_relationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointid,
                                           t_fromobjectid,
                                           t_newlegalentityid);

        api.pkg_relationshipupdate.remove(a_relationshipid);

        --If copying an LE that is not a top level Licensee or Applicant Remove the Parent Relationship
        --that is Created When Copying Relationships
        BEGIN
            SELECT le.parentobjectid
              INTO t_oldparentobjid
              FROM query.o_legalentity le
             WHERE le.objectid = t_newlegalentityid;

            SELECT r.relationshipid
              INTO t_remrelationshipid
              FROM api.relationships r
             WHERE r.fromobjectid = t_oldparentobjid
               AND r.toobjectid = t_newlegalentityid;

            api.pkg_relationshipupdate.remove(t_remrelationshipid);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;
    END;

    /*---------------------------------------------------------------------------
     * LegalEntityLookupDelete() - PUBLIC
     *  This procedure is used to return the relationship to delete when a a Legal
     *  Entity is removed from an Application or License.
     *-------------------------------------------------------------------------*/
    FUNCTION legalentitylookupdelete(a_jobid udt_id, a_rowobjectid udt_id)
        RETURN udt_id
    IS
        t_parentobjectid   udt_id;
        t_relationshipid   udt_id;
    BEGIN
        t_parentobjectid   :=
            api.pkg_columnquery.VALUE(a_rowobjectid, 'ParentObjectId');

        -- Determine if we are removing a top-level Legal Entity or not
        IF t_parentobjectid IS NOT NULL THEN
            SELECT r.relationshipid
              INTO t_relationshipid
              FROM api.relationships r
             WHERE r.endpointid IN
                       (gc_officerep, gc_spouse1ep, gc_stockholderep)
               AND r.fromobjectid = t_parentobjectid
               AND r.toobjectid = a_rowobjectid;
        ELSE
            SELECT r.relationshipid
              INTO t_relationshipid
              FROM api.relationships r
             WHERE r.endpointid IN (gc_licenseele,
                                    gc_applicantle,
                                    gc_managerle,
                                    gc_foodlesseele,
                                    gc_foodlesseelelic,
                                    gc_licmanagerle)
               AND r.fromobjectid = a_jobid
               AND r.toobjectid = a_rowobjectid;
        END IF;

        RETURN t_relationshipid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- All binds are evaluated before an expression is run, therefore
            -- this is needed.
            RETURN 0;
    END legalentitylookupdelete;

    /*---------------------------------------------------------------------------
    * LELookUpCopy() -- PUBLIC
    * This is run on construction of the LEParentChildCopy Relationship
    * rel to copy over a lookuped LE structure to a new licensee
    *-------------------------------------------------------------------------*/
    PROCEDURE lelookupcopy(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_copyleobjid     udt_id;
        t_endpointid      udt_id;
        t_parentleobjid   udt_id;
        t_copytoparent    udt_id;
        t_removerel       udt_id;
    BEGIN
        --Get the parent of the copy rel and find its parent.

        SELECT lec.leparentcopyobjectid, lec.lechildcopyobjectid
          INTO t_parentleobjid, t_copyleobjid
          FROM query.r_leparentchildcopy lec
         WHERE lec.relationshipid = a_relationshipid;

        SELECT le.parentobjectid
          INTO t_copytoparent
          FROM query.o_legalentity le
         WHERE le.objectid = t_parentleobjid;

        /*select r.EndPointId
          into t_EndpointId
          from api.relationships r
         where r.FromObjectId = t_CopytoParent
           and r.EndPointId in (gc_OfficerEndPoint, gc_StockholderEndPoint);*/
        SELECT CASE
                   WHEN le.lestructurerel = 'Officer' THEN
                       gc_officerendpoint
                   WHEN le.lestructurerel = 'Stockholder' THEN
                       gc_stockholderendpoint
               END
          INTO t_endpointid
          FROM query.o_legalentity le
         WHERE le.objectid = t_parentleobjid;

        /*  --Find the LE that the LELookup was used on

          select r.RelationshipId
            into t_RemoveRel
            from api.relationships r
           where r.FromObjectId = t_ParentLeObjId
             and r.ToObjectId = t_CopyLeObjId;*/

        lecopy(a_relationshipid,
               t_copyleobjid,
               t_copytoparent,
               t_endpointid,
               TRUE);

        api.pkg_relationshipupdate.remove(a_relationshipid);

        --api.pkg_relationshipupdate.Remove(t_RemoveRel);
        api.pkg_objectupdate.remove(t_parentleobjid);
    END lelookupcopy;

    /*-----------------------------------------------------------------------
    * LECopy() -- Public
    * LECopy is a wrapper for the LegalEntityCopy Procedure
    * LECopy runs when copying a LE structure to a new license or application
    *------------------------------------------------------------------------*/
    PROCEDURE lecopy(a_relationshipid udt_id,
                     a_copyleobjid   udt_id,
                     a_copytoleobjid udt_id,
                     a_endpointid    udt_id,
                     a_lookup        BOOLEAN DEFAULT FALSE)
    IS
        t_targetlegalentityid   udt_id;
        t_newlegalentityid      udt_id;
        t_endpointid            udt_id;
        t_fromobjectid          udt_id;
        t_relationshipid        udt_id;
        t_masterlicenseid       udt_id;
        t_p12amasterlicense     udt_id;
        t_p12amasterleidold     udt_id;
        t_p12aarray             udt_p12alist;
    BEGIN
        t_targetlegalentityid   := a_copyleobjid;

        t_newlegalentityid      :=
            legalentitycopy(t_targetlegalentityid,
                            t_p12amasterlicense,
                            t_p12amasterleidold,
                            t_p12aarray,
                            TRUE);

        t_endpointid            := a_endpointid;

        t_relationshipid        :=
            api.pkg_relationshipupdate.new(t_endpointid,
                                           a_copytoleobjid,
                                           t_newlegalentityid);

        --Copy all stored dynamic details from existing Stockholder Legal Entity to
        --  new Stockholder Legal Entity

        pkg_copy.copystoredobjdetailsexception(
            t_targetlegalentityid,
            t_newlegalentityid,
            'HierarchyLevel_Stored,FromObjectId');
    END lecopy;

    /*---------------------------------------------------------------------------
    * P12ALookupCopy() -- PUBLIC
    * This is run on construction of the P12AStockholderParentCopy Relationship
    * rel to copy over a lookuped P12A to a new license
    *-------------------------------------------------------------------------*/
    PROCEDURE p12alookupcopy(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_copyleobjid     udt_id;
        t_endpointid      udt_id;
        t_parentleobjid   udt_id;
    BEGIN
        t_endpointid   := gc_p12astockendpoint;

        SELECT spc.p12aparentcopyobjectid, spc.p12astockholdercopyobjectid
          INTO t_parentleobjid, t_copyleobjid
          FROM query.r_p12astockholderparentcopy spc
         WHERE spc.relationshipid = a_relationshipid;

        p12acopy(a_relationshipid,
                 t_copyleobjid,
                 t_parentleobjid,
                 t_endpointid,
                 TRUE);

        api.pkg_relationshipupdate.remove(a_relationshipid);
    END;


    /*-----------------------------------------------------------------------
    * P12ACopy() -- Public
    * P12A is a new wrapper for the LegalEntityCopy Procedure
    * P12ACopy runs when creating a P12A
    * P12ACopy runs when a change is made to the P12A structure
    * P12ACopy is called from P12ALookupCopy when lookup P12A is used
    *------------------------------------------------------------------------*/
    PROCEDURE p12acopy(a_relationshipid udt_id,
                       a_copyleobjid   udt_id,
                       a_copytoleobjid udt_id,
                       a_endpointid    udt_id,
                       a_lookup        BOOLEAN DEFAULT FALSE,
                       a_maintain      BOOLEAN DEFAULT FALSE)
    IS
        t_targetlegalentityid   udt_id;
        t_newlegalentityid      udt_id;
        t_endpointid            udt_id;
        t_fromobjectid          udt_id;
        t_relationshipid        udt_id;
        t_masterlicenseid       udt_id;
        t_p12amasterlicense     udt_id;
        t_p12amasterleidold     udt_id;
        t_p12aarray             udt_p12alist;
    BEGIN
        IF a_lookup = FALSE THEN
            SELECT r.toobjectid
              INTO t_targetlegalentityid
              FROM api.relationships  r
                   JOIN api.objects o ON o.objectid = r.toobjectid
             WHERE r.relationshipid = a_relationshipid
               AND o.objectdefid =
                   api.pkg_configquery.objectdefidforname('o_LegalEntity')
               AND r.fromobjectid = a_copyleobjid
               AND r.endpointid IN (gc_officerendpoint,
                                    gc_lespouse2,
                                    gc_stockholderendpoint,
                                    gc_p12astockendpoint);
        ELSE
            t_targetlegalentityid   := a_copyleobjid;
        END IF;

        t_newlegalentityid   :=
            legalentitycopy(t_targetlegalentityid,
                            t_p12amasterlicense,
                            t_p12amasterleidold,
                            t_p12aarray,
                            TRUE,
                            a_maintain);

        t_endpointid   := a_endpointid;

        t_relationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointid,
                                           a_copytoleobjid,
                                           t_newlegalentityid);

        --Copy all stored dynamic details from existing Stockholder Legal Entity to
        --  new Stockholder Legal Entity

        pkg_copy.copystoredobjdetailsexception(
            t_targetlegalentityid,
            t_newlegalentityid,
            'HierarchyLevel_Stored,FromObjectId');

        IF a_maintain = TRUE THEN
            IF t_endpointid = gc_p12astockendpoint THEN
                INSERT INTO p12alog_t t
                     VALUES (t_newlegalentityid, a_copyleobjid);
            END IF;
        END IF;

        IF a_lookup = TRUE THEN
            INSERT INTO p12alog_t t
                 VALUES (t_newlegalentityid, a_copyleobjid);

            SELECT le.p12amasterlicensejobid
              INTO t_masterlicenseid
              FROM query.o_legalentity le
             WHERE le.objectid = a_copyleobjid;

            api.pkg_columnupdate.setvalue(t_newlegalentityid,
                                          'P12AStatus',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_newlegalentityid,
                                          'P12AMasterLicenseJobId',
                                          t_masterlicenseid);
        END IF;
    END p12acopy;

    --*------------------------------------------------------------------------------------------------
    --* GetP12LicForLE() -- PUBLIC
    --* Find the P12 Applications with which the P12 Master legal entity is associated.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getp12appforle(a_objectid         udt_id,
                             a_endpointid       udt_id,
                             a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_leobjectid               udt_id;
        t_p12applicantendpointid   udt_id;
        t_topparentleobjectid      udt_id;
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();
        t_p12applicantendpointid   :=
            api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                  'P12Application');

        FOR c
            IN (SELECT r.toobjectid
                  FROM api.relationships  r
                       JOIN query.r_legalentityroot r2
                           ON r2.rootobjectid = r.fromobjectid
                 WHERE r2.nodeobjectid = a_objectid
                   AND r.endpointid = t_p12applicantendpointid)
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.toobjectid);
        END LOOP;
    END getp12appforle;

    --*------------------------------------------------------------------------------------------------
    --* GetP12AppForLE() -- PUBLIC
    --* Find the non-master P12 Licenses with which the P12 Master Legal Entity is associated.
    --*------------------------------------------------------------------------------------------------

    PROCEDURE getp12licforle(a_objectid         udt_id,
                             a_endpointid       udt_id,
                             a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_p12licenseeendpointid   udt_id;
        t_leobjectid              udt_id;
        t_topparentleobjectid     udt_id;
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c
            IN (SELECT r.licensejobid
                  FROM query.r_licenseprimaryp12legalentity  r
                       JOIN query.r_legalentityroot r2
                           ON r2.rootobjectid = r.primayrp12leobjectid
                 WHERE r2.nodeobjectid = a_objectid
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_p12license tr
                             WHERE tr.p12license1objectid = r.licensejobid))
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.licensejobid);
        END LOOP;
    END getp12licforle;

    /*---------------------------------------------------------------------------
     * LRAuditDestructor() -- PUBLIC
     *   Attach this to the Destructor of an Legal Entity
     *   Created because LEs are procedurally deleted and thus their columns couldn't be checked on deletion.
     *-------------------------------------------------------------------------*/
    PROCEDURE leauditdestructor(a_objectid      udt_id,
                                a_asofdate      DATE,
                                a_auditcolumns  VARCHAR2,
                                a_auditrelationshipnames VARCHAR2,
                                a_omitprefix    VARCHAR2 DEFAULT NULL)
    IS
        g_auditremove   CONSTANT PLS_INTEGER := 3;
    BEGIN
        IF a_auditrelationshipnames IS NULL
       AND a_auditcolumns IS NULL THEN
            RETURN;
        /* I don't know why we are calling this procedure if the above is true! */
        END IF;
    --extension.pkg_objectaudit.Audit(a_ObjectId, a_AsOfDate, null, null, null, g_AuditRemove);
    END leauditdestructor;

    --ryan: what happens now that I am not taking relationshipdefs?

    /*------------------------------
    -- LogNameChange ()
    -- This will run as a deferred procedure on change
    --  of the dup_FormattedName column on the Legal Entity.
    -- This will update the dup column on related Licenses/Applications.
    */
    ------------------------------
    PROCEDURE lognamechange(a_objectid udt_id, a_asofdate DATE)
    IS
        t_columnname   VARCHAR2(100);
    BEGIN
        FOR c
            IN (SELECT le.dup_formattedname,
                       lle.licensejobid jobid,
                       'L'              jobtype
                  FROM query.o_legalentity  le
                       JOIN query.r_licenselegalentitylicensee lle
                           ON lle.legalentityobjectid = le.objectid
                 WHERE le.objectid = a_objectid
                UNION
                SELECT le.dup_formattedname,
                       ple.licensejobid jobid,
                       'L'              jobtype
                  FROM query.o_legalentity  le
                       JOIN query.r_licensep12legalentity ple
                           ON ple.legalentityobjectid = le.objectid
                 WHERE le.objectid = a_objectid
                UNION
                SELECT le.dup_formattedname,
                       ale.applicationobjectid jobid,
                       'A'                     jobtype
                  FROM query.o_legalentity  le
                       JOIN query.r_applicationlegalentityapp ale
                           ON ale.legalentityobjectid = le.objectid
                 WHERE le.objectid = a_objectid
                UNION
                SELECT le.dup_formattedname,
                       aple.applicationjobid jobid,
                       'A'                   jobtype
                  FROM query.o_legalentity  le
                       JOIN query.r_applicationp12legalentity aple
                           ON aple.legalentityobjectid = le.objectid
                 WHERE le.objectid = a_objectid)
        LOOP
            IF c.jobtype = 'A' THEN
                t_columnname   := 'dup_ApplicantNames';
            ELSIF c.jobtype = 'L' THEN
                t_columnname   := 'dup_LicenseeNames';
            END IF;

            api.pkg_columnupdate.setvalue(c.jobid,
                                          t_columnname,
                                          c.dup_formattedname);
        END LOOP;
    END;

    /*---------------------------------------------------------------------------
     * GetLegalEntityIdForRel() - PRIVATE
     *  This function is used to obtain the Legal Entity Id on deletion of a Legal
     *  Entity relationship on an Application or License. It is autonomous to get
     *  around a timing issue.
     *-------------------------------------------------------------------------*/
    FUNCTION getlegalentityidforrel(a_relationshipid udt_id)
        RETURN udt_id
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        t_legalentityid        udt_id := 0;
        t_appapplicaint        udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'AppApplication');
        t_osmapplicaint        udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'OSMApplication');
        t_foodlesseeapp       udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'FoodLesseeApplication');
        t_legalentitylic       udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'LegalEntityLicense');
        t_osmlicensee          udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'OSMLicense');
        t_foodlesseelic       udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'FoodLesseeLicense');
        t_officerlegalentity   udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'OfficerParentEntity');
        t_stockholderentity    udt_id
            := api.pkg_configquery.endpointidforname(
                   'o_LegalEntity',
                   'StockholderParentEntity');
        t_spouselegalentity    udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Spouse1');
    BEGIN
        FOR x IN (SELECT r.fromobjectid
                    --                into t_LegalEntityId
                    FROM api.relationships r
                   WHERE r.relationshipid = a_relationshipid
                     AND r.endpointid IN (t_appapplicaint,
                                          t_osmapplicaint,
                                          t_foodlesseeapp,
                                          t_legalentitylic,
                                          t_osmlicensee,
                                          t_foodlesseelic,
                                          t_officerlegalentity,
                                          t_stockholderentity,
                                          t_spouselegalentity))
        LOOP
            t_legalentityid   := x.fromobjectid;
        END LOOP;

        RETURN t_legalentityid;
    END getlegalentityidforrel;

    /*---------------------------------------------------------------------------
     * MarkForDeletion() - PUBLIC
     *  This procedure is used on deletion of the stored relationships between the
     *  Legal Entity and an Application or License respectively. It is used by
     *  sitespecific.pkg_Schedule.CleanLegalEntities to remove orphaned Legal Entities.
     *-------------------------------------------------------------------------*/
    PROCEDURE markfordeletion(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_legalentityid   udt_id;
    BEGIN
        t_legalentityid   := getlegalentityidforrel(a_relationshipid);

        IF t_legalentityid > 0 THEN
            api.pkg_columnupdate.setvalue(t_legalentityid,
                                          'ShouldDelete',
                                          'Y');
        END IF;
    END markfordeletion;

    FUNCTION getlicorappforle(a_leobjid NUMBER)
        RETURN NUMBER
    IS
        t_licobjid        udt_id;
        t_licensesobjid   api.udt_objectlist;
    BEGIN
        getlicforle(a_leobjid, NULL, t_licensesobjid);

        IF t_licensesobjid.COUNT > 0 THEN
            t_licobjid   := t_licensesobjid(1).objectid;
        ELSE
            getappforle(a_leobjid, NULL, t_licensesobjid);

            IF t_licensesobjid.COUNT > 0 THEN
                t_licobjid   := t_licensesobjid(1).objectid;
            ELSE
                t_licobjid   := NULL;
            END IF;
        END IF;

        RETURN t_licobjid;
    END getlicorappforle;

    /*********************************************************
    * Procedure LEStructureCopyNew()
    * This is used to copy existing legal entity structure to
    * a new application or license, but it does not work with
    * any of the P12 structure.
    * Created by: Daniel Magill
    * Created Date: 10/22/2015
    **********************************************************/
    PROCEDURE lestructurecopynew(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_newlegalentityid      udt_id;
        t_targetlegalentityid   udt_id;
        t_legalentities         udt_legalentityrel;

        t_compreldefid          udt_id;
        t_endpointid            udt_id;
        t_legalentitydefid      udt_id;
        t_lesortkey             NUMBER;
        t_level                 NUMBER;
        t_newcloneobjid         udt_id;
        t_newrelobjectid        udt_id;
        t_perreldefid           udt_id;
        t_reldefid              udt_id;
        t_spousereldefid        udt_id;
        t_stkreldefid           udt_id;
        t_titlereldefid         udt_id;
        t_parentid              udt_id;
        t_childid               udt_id;

        TYPE lelisttype IS TABLE OF NUMBER
            INDEX BY PLS_INTEGER;                         -- Associative Array

        legalentityxref         lelisttype;
        parentxref              lelisttype;
        childxref               lelisttype;
    BEGIN
        --TargetLegalEntityId is the LE that we find in the lookup
        --NewLegalEntity is the LE that we have just created and added a temp relationship to
        SELECT r.tolegalentity, r.fromlegalentity
          INTO t_targetlegalentityid, t_newlegalentityid
          FROM query.r_templegalentity r
         WHERE r.relationshipid = a_relationshipid;

        --If the user attempts to relate an Entity that is a P12, then raise an error and tell them where they should go to do this.
        /* if api.pkg_ColumnQuery.Value(t_TargetLegalEntityId, 'P12Status') = 'Y' then
           api.pkg_relationshipupdate.Remove(a_RelationshipId);
           api.pkg_Errors.RaiseError(-20000, 'You cannot link to a P12 from here. Please click Cancel and use the Lookup P12 Legal Entity link.');
         end if;*/

        -- no need to fire any post-verifies on the source object!
        pkg_legalentityobject.markprocessed(t_targetlegalentityid);

        t_legalentities                       := getlegalentitychildrennew(t_targetlegalentityid);
        t_stkreldefid                         :=
            api.pkg_configquery.objectdefidforname(
                'r_StockholderLimitedPartner');
        t_perreldefid                         :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityPerson');
        t_compreldefid                        :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityCompany');
        t_titlereldefid                       :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityTitle');
        t_legalentitydefid                    :=
            api.pkg_configquery.objectdefidforname('o_LegalEntity');


        legalentityxref(t_newlegalentityid)   := t_newlegalentityid;

        -- Find and copy all the existing relationship for t_TargetLegalEntity to Person objects, or Company objects
        -- to the New Legal Entity that we are cloning from the TargetLegalEntity
        FOR c
            IN (SELECT rel.relationshipdefid,
                       rel.fromobjectid,
                       rel.endpointid
                  FROM api.relationships rel
                 WHERE rel.toobjectid = t_targetlegalentityid
                   AND rel.relationshipdefid IN
                           (t_perreldefid, t_compreldefid, t_titlereldefid))
        LOOP
            t_newrelobjectid   :=
                api.pkg_relationshipupdate.new(
                    c.endpointid,
                    c.fromobjectid,
                    legalentityxref(t_newlegalentityid));
        END LOOP;

        t_level                               := 1;
        parentxref(t_level)                   := t_newlegalentityid;

        LOOP
            FETCH t_legalentities
                INTO t_endpointid, t_parentid, t_childid, t_level;

            EXIT WHEN t_legalentities%NOTFOUND;

            --Don't duplicate the Temporary relationship
            IF t_endpointid NOT IN
                   (api.pkg_configquery.endpointidforname('o_legalentity',
                                                          'TempLegalEntity1'),
                    api.pkg_configquery.otherendpointidforname(
                        'o_legalentity',
                        'TempLegalEntity1')) THEN
                -- This will create a new object (i.e. the spouse LE) that also will need to be cloned
                -- from the existing object (the spouse LE) and need the relationships copied over
                t_newcloneobjid      :=
                    api.pkg_objectupdate.new(t_legalentitydefid);
                childxref(t_level)   := t_newcloneobjid;

                -- Create a Stored rel directly to the Root of the structure
                t_newrelobjectid     :=
                    api.pkg_relationshipupdate.new(gc_rootep,
                                                   t_newcloneobjid,
                                                   t_newlegalentityid);

                --Copy all stored dynamic details from existing Stockholder Legal Entity to
                --  new Stockholder Legal Entity
                SELECT rel.relationshipdefid
                  INTO t_reldefid
                  FROM api.relationshipdefs rel
                 WHERE rel.toendpointid = t_endpointid;

                -- api.pkg_errors.RaiseError(-20000, 'Copy LE Structure New: ' ||  t_StkRelDefId || ' Real Def: ' || t_RelDefId || ' Legal Entity: ' || api.pkg_columnquery.value(t_ParentId , 'dup_FormattedName'));
                IF t_reldefid = t_stkreldefid THEN
                    -- Always exclude the FromObjectId because we are always adding to the current hierarchy.
                    pkg_copy.copystoredobjdetailsexception(
                        t_childid,
                        childxref(t_level),
                        'HierarchyLevel_Stored,FromObjectId');
                END IF;

                --   Find all existing relationships for t_ChildId Legal Entity
                --   Relate to existing company, person, title objects
                FOR c2
                    IN (SELECT rel2.relationshipdefid,
                               rel2.fromobjectid,
                               rel2.endpointid
                          FROM api.relationships rel2
                         WHERE rel2.toobjectid = t_childid
                           AND rel2.relationshipdefid IN
                                   (t_perreldefid,
                                    t_compreldefid,
                                    t_titlereldefid))
                LOOP
                    -- Only create relationship to new Cloned Object
                    -- don't create a new object for person, company, title
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(c2.endpointid,
                                                       c2.fromobjectid,
                                                       childxref(t_level));
                END LOOP;

                -- Relate the two newly created Legal Entities.
                t_newrelobjectid     :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   parentxref(t_level),
                                                   childxref(t_level));
            END IF;

            parentxref(t_level + 1)   := childxref(t_level);
        END LOOP;

        CLOSE t_legalentities;

        api.pkg_relationshipupdate.remove(a_relationshipid);
    END lestructurecopynew;

    PROCEDURE fromobjectidcolumnchange(a_objectid udt_id, a_asofdate DATE)
    IS
        t_fromobjectid   udt_id;
        t_rootid         udt_id;
        t_relid          udt_id;
    BEGIN
        t_fromobjectid   :=
            api.pkg_columnquery.VALUE(a_objectid, 'FromObjectId');

        -- get From Object Id's Root Id.
        SELECT rootobjectid
          INTO t_rootid
          FROM query.r_legalentityroot
         WHERE nodeobjectid = t_fromobjectid;

        pkg_legalentityobject.replacerootrel(a_objectid, t_rootid);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END;


    /*---------------------------------------------------------------------------
     * AddOfficerStockolderInfo() -- PUBLIC
     * When a new officer or stockholder information is filled in, the appropriate
     * relationships for officers, stockholders, persons and spouses
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE addofficerstockolderinfo(a_objectid udt_id, a_asofdate DATE)
    IS
        t_temprelationshipid       udt_id;
        t_ownertype                VARCHAR2(4000);
        t_titlecount               NUMBER;
        t_officerendpointid        udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Officer');
        t_stockholderendpointid    udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Stockholder');
        t_legalentitydefid         udt_id
            := api.pkg_configquery.objectdefidforname('o_LegalEntity');
        t_personendpointid         udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Person');
        t_companyendpointid        udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Company');
        t_spouse1endpointid        udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Spouse1');
        t_newlegalentityid         udt_id;
        t_officerrelid             udt_id;
        t_stockholderrelid         udt_id;
        t_personrelid              udt_id;
        t_personobjectid           udt_id;
        t_companyobjectid          udt_id;
        t_companyrelid             udt_id;
        t_fromobjectid             udt_id;
        t_tempcopypersonrelcount   NUMBER;
        t_objectnames              VARCHAR2(4000);
        t_relexists                BOOLEAN;
        t_stockholderspouseleid    udt_id;
        t_stockholderspouserelid   udt_id;
        t_stockholderpersonrelid   udt_id;
        t_spouseobjectid           udt_id;
        t_officerrelcount          NUMBER;
        t_relatedobjectids         api.udt_objectlist;
    BEGIN
        t_fromobjectid       :=
            api.pkg_columnquery.numericvalue(a_objectid, 'FromObjectId');
        t_relatedobjectids   := api.udt_objectlist();

        IF t_fromobjectid IS NOT NULL
       AND api.pkg_columnquery.VALUE(a_objectid, 'AddOfficerStockholderInfo') =
           'Y'
       AND gc_relobjscreated.EXISTS('r_LegalEntitySpouse') = FALSE THEN
            t_ownertype   :=
                api.pkg_columnquery.VALUE(a_objectid, 'OwnerType');
            t_titlecount   :=
                api.pkg_columnquery.numericvalue(a_objectid, 'TitleCount');
            t_personobjectid   :=
                api.pkg_columnquery.numericvalue(a_objectid,
                                                 'PersonObjectId');
            t_companyobjectid   :=
                api.pkg_columnquery.numericvalue(a_objectid,
                                                 'CompanyObjectId');

            IF t_ownertype IS NULL
           AND t_titlecount > 0 THEN
                --Just officer information provided, only create the r_OfficerGenPartnerPrincipal relationship
                t_officerrelid   :=
                    api.pkg_relationshipupdate.new(t_officerendpointid,
                                                   t_fromobjectid,
                                                   a_objectid);
            ELSIF t_ownertype IS NOT NULL
              AND t_titlecount = 0 THEN
                --Just stockholder information provided, only create the r_StockholderLimitedPartner relationship
                t_stockholderrelid   :=
                    api.pkg_relationshipupdate.new(t_stockholderendpointid,
                                                   t_fromobjectid,
                                                   a_objectid);
            ELSIF t_ownertype IS NOT NULL
              AND t_titlecount > 0 THEN
                /*Both officer and stockholder information provided:
                 *  1) Create the r_OfficerGenPartnerPrincipal relationship
                 *  2) Create a new Legal Entity object and copy the two stockholder fields
                 *  3) Create a new Person relationship between the new legal entity and current person object id
                 *  4) Create a new r_StockholderLimitedPartner relationship between current and new legal entity */

                t_newlegalentityid   :=
                    api.pkg_objectupdate.new(t_legalentitydefid);

                copylegalentity(a_objectid, t_newlegalentityid);

                t_officerrelid   :=
                    api.pkg_relationshipupdate.new(t_officerendpointid,
                                                   t_fromobjectid,
                                                   a_objectid);

                --Update the new entity with ownership info
                api.pkg_columnupdate.setvalue(
                    t_newlegalentityid,
                    'OwnerType',
                    api.pkg_columnquery.VALUE(a_objectid, 'OwnerType'));
                api.pkg_columnupdate.setvalue(
                    t_newlegalentityid,
                    'PercentageOfOwnership',
                    api.pkg_columnquery.numericvalue(a_objectid,
                                                     'PercentageOfOwnership'));

                --Remove ownership info from existing entity
                api.pkg_columnupdate.removevalue(a_objectid, 'OwnerType');
                api.pkg_columnupdate.removevalue(a_objectid,
                                                 'PercentageOfOwnership');

                IF t_personobjectid IS NULL
               AND t_companyobjectid IS NULL THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'Please add a Person or Company');
                ELSIF t_personobjectid IS NOT NULL THEN
                    --check if spouse is available, if it is, then create a new legal entity and create relationships for a spouse
                    IF api.pkg_columnquery.VALUE(t_newlegalentityid,
                                                 'SpouseName')
                           IS NULL THEN
                        t_spouseobjectid   :=
                            NVL(
                                api.pkg_columnquery.numericvalue(
                                    a_objectid,
                                    'SpouseObjectId'),
                                api.pkg_columnquery.numericvalue(
                                    a_objectid,
                                    'SpouseObjectIdTemp'));

                        IF (t_spouseobjectid IS NOT NULL) THEN
                            t_stockholderspouseleid   :=
                                api.pkg_objectupdate.new(t_legalentitydefid);
                            t_stockholderspouserelid   :=
                                api.pkg_relationshipupdate.new(
                                    t_spouse1endpointid,
                                    t_newlegalentityid,
                                    t_stockholderspouseleid);
                            t_stockholderpersonrelid   :=
                                api.pkg_relationshipupdate.new(
                                    t_personendpointid,
                                    t_stockholderspouseleid,
                                    t_spouseobjectid);
                        END IF;
                    END IF;
                END IF;

                t_stockholderrelid   :=
                    api.pkg_relationshipupdate.new(t_stockholderendpointid,
                                                   t_fromobjectid,
                                                   t_newlegalentityid);
            ELSE
                api.pkg_errors.raiseerror(
                    -20000,
                    'Please provide either officer and/or stockholder information.');
            END IF;

            api.pkg_columnupdate.setvalue(a_objectid,
                                          'AddOfficerStockholderInfo',
                                          'N');
        END IF;

        -- Maintain duplicate Details. This is run at the end of this procedure ot make sure that the hierarchy is correctly update

        getlegalentitychildren(a_objectid, t_relatedobjectids);

        FOR i IN 1 .. t_relatedobjectids.COUNT()
        LOOP
            sitespecific.pkg_apibreaks.maintainduplicatedetails(
                t_relatedobjectids(i).objectid);
        END LOOP;
    END addofficerstockolderinfo;


    /*---------------------------------------------------------------------------
     * CopySpouse() -- PUBLIC
     * When a spouse is found through a lookup, a temporary relationship is created
     * and this process will take that temp relationship and create a new legal entity
     * and appropriate spouse and person relationships since a spouse can only be connected
     * through a spouse relationship between two legal entities
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE copyspouse(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_currentlegalentityid   udt_id;
        t_newpersonid            udt_id;
        t_newlegalentityid       udt_id;
        t_legalentitydefid       udt_id;
        t_spouse1endpointid      udt_id;
        t_spouse1relid           udt_id;
        t_personrelid            udt_id;
        t_personendpointid       udt_id;
    BEGIN
        --if the temporary relationship id exists in the current scope, do not run additional logic
        IF gc_relobjscreated.EXISTS(a_relationshipid) THEN
            RETURN;
        ELSE
            --Get the Legal Entity Id and Person Id
            SELECT r.currentleid, r.newspouseid
              INTO t_currentlegalentityid, t_newpersonid
              FROM query.r_tempcopyperson r
             WHERE r.relationshipid = a_relationshipid;

            --Create a new legal entity
            t_legalentitydefid                         :=
                api.pkg_configquery.objectdefidforname('o_LegalEntity');
            t_newlegalentityid                         :=
                api.pkg_objectupdate.new(t_legalentitydefid);

            --Create a new relationship from the current legal entity to new legal entity (Spouse1)
            t_spouse1endpointid                        :=
                api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                      'Spouse1');
            t_spouse1relid                             :=
                api.pkg_relationshipupdate.new(t_spouse1endpointid,
                                               t_currentlegalentityid,
                                               t_newlegalentityid);

            --Create a new relationship from the new legal entity to the new person (Person)
            t_personendpointid                         :=
                api.pkg_configquery.endpointidforname('o_legalentity',
                                                      'Person');
            t_personrelid                              :=
                api.pkg_relationshipupdate.new(t_personendpointid,
                                               t_newlegalentityid,
                                               t_newpersonid);

            --Add the relationship just created to the associative array
            gc_relobjscreated('r_LegalEntitySpouse')   := t_personrelid;
        END IF;
    END copyspouse;

    /*---------------------------------------------------------------------------
     * DeleteSpouse() -- PUBLIC
     * This procedure removes any relationships to a spouse from the legal entity
     * There may be several types of relationships: temp, spouse1 or in the case
     * of adding a legal entity to an existing entity, a person object id
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE deletespouse(a_objectid udt_id, a_asofdate DATE)
    IS
        t_toobjectid           udt_id;
        t_spouseobjectidtemp   udt_id;
        t_tempspouserelid      api.pkg_definition.udt_idlist;
        t_personobjectid       udt_id;
        t_personrelid          udt_id;
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_objectid, 'SpouseDelete') = 'Y') THEN
            t_spouseobjectidtemp   :=
                api.pkg_columnquery.numericvalue(a_objectid,
                                                 'SpouseObjectIdTemp');

            IF t_spouseobjectidtemp IS NOT NULL THEN
                SELECT r.relationshipid
                  BULK COLLECT INTO t_tempspouserelid
                  FROM api.relationships r
                 WHERE r.toobjectid = t_spouseobjectidtemp;

                FOR i IN 1 .. t_tempspouserelid.COUNT
                LOOP
                    api.pkg_relationshipupdate.remove(t_tempspouserelid(i));
                END LOOP;
            ELSIF api.pkg_columnquery.numericvalue(a_objectid,
                                                   'SpouseObjectId')
                      IS NOT NULL THEN
                SELECT DISTINCT r.toobjectid
                  INTO t_toobjectid
                  FROM api.relationships  r
                       JOIN api.relationshipdefs d
                           ON r.relationshipdefid = d.relationshipdefid
                 WHERE r.fromobjectid = a_objectid
                   AND d.name IN ('r_LegalEntitySpouse');

                api.pkg_objectupdate.remove(t_toobjectid, SYSDATE);
            ELSE
                t_personobjectid   :=
                    api.pkg_columnquery.numericvalue(a_objectid,
                                                     'PersonObjectId');

                SELECT r.relationshipid
                  INTO t_personrelid
                  FROM api.relationships r
                 WHERE r.toobjectid = t_personobjectid;

                api.pkg_relationshipupdate.remove(t_personrelid);
            END IF;

            api.pkg_columnupdate.setvalue(a_objectid, 'SpouseDelete', 'N');
        END IF;
    END;

    /*---------------------------------------------------------------------------
     * DeletePerson() -- PUBLIC
     * This procedure removes any person and associated spouses from the legal entity
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE deleteperson(a_objectid udt_id, a_asofdate DATE)
    IS
        t_relationshipid   udt_id;
        t_temprelcount     NUMBER;
        t_spouseleid       udt_id;
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_objectid, 'PersonDelete') = 'Y') THEN
            SELECT r.relationshipid
              INTO t_relationshipid
              FROM query.r_legalentityperson r
             WHERE r.legalentityobjectid = a_objectid;

            api.pkg_relationshipupdate.remove(t_relationshipid);

            SELECT COUNT(*)
              INTO t_temprelcount
              FROM api.relationships  r
                   JOIN api.endpoints e ON e.endpointid = r.endpointid
             WHERE e.name = 'Spouse1'
               AND r.fromobjectid = a_objectid;

            --if a spouse exists remove him/her
            IF t_temprelcount > 0 THEN
                SELECT DISTINCT r.toobjectid
                  INTO t_spouseleid
                  FROM api.relationships  r
                       JOIN api.relationshipdefs d
                           ON r.relationshipdefid = d.relationshipdefid
                 WHERE r.fromobjectid = a_objectid
                   AND d.name = 'r_LegalEntitySpouse';

                api.pkg_objectupdate.remove(t_spouseleid, SYSDATE);
            END IF;

            api.pkg_columnupdate.setvalue(a_objectid, 'PersonDelete', 'N');
        END IF;
    END;

    /*---------------------------------------------------------------------------
     * DeleteCompany() -- PUBLIC
     * This procedure removes any company from the legal entity
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE deletecompany(a_objectid udt_id, a_asofdate DATE)
    IS
        t_relationshipid   udt_id;
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_objectid, 'CompanyDelete') = 'Y') THEN
            SELECT r.relationshipid
              INTO t_relationshipid
              FROM query.r_legalentitycompany r
             WHERE r.legalentityobjectid = a_objectid;


            api.pkg_relationshipupdate.remove(t_relationshipid);

            api.pkg_columnupdate.setvalue(a_objectid, 'CompanyDelete', 'N');
        END IF;
    END;

    /*--------------------------------------------------------------------------------------------
     * DeleteCompany() -- PUBLIC
     * This procedure fires on the legal entity post verify.  If this legal entity is
     * adding an officer and/or shareholder the AddOfficerStockholderInfo procedure will be called
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------------------------*/
    PROCEDURE lepostverify(a_objectid udt_id, a_asofdate DATE)
    IS
    BEGIN
        IF api.pkg_columnquery.VALUE(a_objectid, 'AddOfficerStockholderInfo') =
           'Y' THEN
            addofficerstockolderinfo(a_objectid, a_asofdate);
        END IF;
    END;

    /*--------------------------------------------------------------------------------------------
     * CopyLegalEntity()
     * This function will copy all relationships and details from one legal entity to another
     * Created by: Yars Tsaytak
     * Created Date: 11/4/15
     *-------------------------------------------------------------------------------------------*/
    PROCEDURE copylegalentity(a_fromobjectid udt_id, a_toobjectid udt_id)
    IS
        t_newlegalentityid      udt_id := a_toobjectid;
        t_targetlegalentityid   udt_id := a_fromobjectid;
        t_legalentities         udt_legalentityrel;

        t_compreldefid          udt_id;
        t_endpointid            udt_id;
        t_legalentitydefid      udt_id;
        t_lesortkey             NUMBER;
        t_level                 NUMBER;
        t_newcloneobjid         udt_id;
        t_newrelobjectid        udt_id;
        t_perreldefid           udt_id;
        t_reldefid              udt_id;
        t_spousereldefid        udt_id;
        t_stkreldefid           udt_id;
        t_titlereldefid         udt_id;
        t_parentid              udt_id;
        t_childid               udt_id;
        t_rootid                udt_id;

        TYPE lelisttype IS TABLE OF NUMBER
            INDEX BY PLS_INTEGER;                         -- Associative Array

        legalentityxref         lelisttype;
        parentxref              lelisttype;
        childxref               lelisttype;
    BEGIN
        t_legalentities                       := getlegalentitychildrennew(t_targetlegalentityid);
        t_stkreldefid                         :=
            api.pkg_configquery.objectdefidforname(
                'r_StockholderLimitedPartner');
        t_perreldefid                         :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityPerson');
        t_compreldefid                        :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityCompany');
        t_titlereldefid                       :=
            api.pkg_configquery.objectdefidforname('r_LegalEntityTitle');
        t_legalentitydefid                    :=
            api.pkg_configquery.objectdefidforname('o_LegalEntity');


        legalentityxref(t_newlegalentityid)   := t_newlegalentityid;

        -- capture Root Legal Entity Object Id so we may add relationships
        -- to each new node from this operation
        t_rootid                              :=
            getrootlegalentity(t_newlegalentityid);

        -- Find and copy all the existing relationship for t_TargetLegalEntity to Person objects, or Company objects
        -- to the New Legal Entity that we are cloning from the TargetLegalEntity
        FOR c
            IN (SELECT rel.relationshipdefid,
                       rel.fromobjectid,
                       rel.endpointid
                  FROM api.relationships rel
                 WHERE rel.toobjectid = t_targetlegalentityid
                   AND rel.relationshipdefid IN
                           (t_perreldefid, t_compreldefid, t_titlereldefid))
        LOOP
            t_newrelobjectid   :=
                api.pkg_relationshipupdate.new(
                    c.endpointid,
                    c.fromobjectid,
                    legalentityxref(t_newlegalentityid));
        END LOOP;

        t_level                               := 1;
        parentxref(t_level)                   := t_newlegalentityid;

        LOOP
            FETCH t_legalentities
                INTO t_endpointid, t_parentid, t_childid, t_level;

            EXIT WHEN t_legalentities%NOTFOUND;

            --Don't duplicate the Temporary relationship
            IF t_endpointid NOT IN
                   (api.pkg_configquery.endpointidforname('o_legalentity',
                                                          'TempLegalEntity1'),
                    api.pkg_configquery.otherendpointidforname(
                        'o_legalentity',
                        'TempLegalEntity1')) THEN
                -- This will create a new object (i.e. the spouse LE) that also will need to be cloned
                -- from the existing object (the spouse LE) and need the relationships copied over
                t_newcloneobjid      :=
                    api.pkg_objectupdate.new(t_legalentitydefid);
                childxref(t_level)   := t_newcloneobjid;

                -- Create a Stored rel directly to the Root of the structure
                t_newrelobjectid     :=
                    api.pkg_relationshipupdate.new(gc_rootep,
                                                   t_newcloneobjid,
                                                   t_rootid);

                --Copy all stored dynamic details from existing Stockholder Legal Entity to
                --  new Stockholder Legal Entity
                SELECT rel.relationshipdefid
                  INTO t_reldefid
                  FROM api.relationshipdefs rel
                 WHERE rel.toendpointid = t_endpointid;

                IF t_reldefid = t_stkreldefid THEN
                    pkg_copy.copystoredobjdetailsexception(
                        t_childid,
                        childxref(t_level),
                        'HierarchyLevel_Stored,FromObjectId');
                END IF;

                --   Find all existing relationships for t_ChildId Legal Entity
                --   Relate to existing company, person, title objects
                FOR c2
                    IN (SELECT rel2.relationshipdefid,
                               rel2.fromobjectid,
                               rel2.endpointid
                          FROM api.relationships rel2
                         WHERE rel2.toobjectid = t_childid
                           AND rel2.relationshipdefid IN
                                   (t_perreldefid,
                                    t_compreldefid,
                                    t_titlereldefid))
                LOOP
                    -- Only create relationship to new Cloned Object
                    -- don't create a new object for person, company, title
                    t_newrelobjectid   :=
                        api.pkg_relationshipupdate.new(c2.endpointid,
                                                       c2.fromobjectid,
                                                       childxref(t_level));
                END LOOP;

                -- Relate the two newly created Legal Entities.
                t_newrelobjectid     :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   parentxref(t_level),
                                                   childxref(t_level));
            END IF;

            parentxref(t_level + 1)   := childxref(t_level);
        END LOOP;

        CLOSE t_legalentities;
    END;
END pkg_legalentity;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_LEGALENTITY TO BIZMOD_API;

GRANT EXECUTE ON SITESPECIFIC.PKG_LEGALENTITY TO POSSEEXTENSIONS;

GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_LEGALENTITY TO PSERVERSYS;

GRANT EXECUTE ON SITESPECIFIC.PKG_LEGALENTITY TO TOOLBOX;
