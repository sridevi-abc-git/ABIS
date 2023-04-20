CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_legalentity
AS
    -- **************************************************************************
    -- File:        PKG_LEGALENTITY.PKS
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

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    TYPE udt_legalentityrelrecord IS RECORD
    (
        endpointid NUMBER,
        fromobjectid NUMBER,
        toobjectid NUMBER,
        LEVEL NUMBER
    );

    TYPE udt_legalentityrel IS REF CURSOR RETURN udt_legalentityrelrecord;

    /*---------------------------------------------------------------------------
    * GetLegalEntityChildren()
    * This procedure gets the children objectids of a legal entity.
    *-------------------------------------------------------------------------*/
    PROCEDURE getlegalentitychildren(
        a_objectid            udt_id,
        a_relatedobjectids IN OUT api.udt_objectlist);

    /*---------------------------------------------------------------------------
    * GetLegalEntityChildren() -- PUBLIC
    *-------------------------------------------------------------------------*/
    FUNCTION getlegalentitychildren(a_objectid udt_id)
        RETURN udt_legalentityrel;

    FUNCTION getlegalentityhierarchy(a_objectid udt_id)
        RETURN udt_legalentityrel;

    /*---------------------------------------------------------------------------
    * GetJobLEChildren() -- PUBLIC
    *-------------------------------------------------------------------------*/
    function GetJobLEChildren(a_ObjectId udt_Id)
      return api.pkg_definition.udt_IdList ;
    
    /*---------------------------------------------------------------------------
    * LegalEntityHierarchy()
    *  This procedure gets the entire hierarchy of related legal entities.
    *-------------------------------------------------------------------------*/
    PROCEDURE legalentityhierarchy(a_objectid         udt_id,
                                   a_endpointid       udt_id,
                                   a_relatedobjectids OUT api.udt_objectlist);

    /*---------------------------------------------------------------------------
    * LegalEntityHierarchyFirstLvl() -- PUBLIC
    * Created by: Andy Patterson (CXUSA)
    * Created on: 9/9/2015
    *  This procedure gets the first level of hierarchy for related legal entities.
    *-------------------------------------------------------------------------*/
    PROCEDURE legalentityhierarchyfirstlvl(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist);

    /*---------------------------------------------------------------------------
    * ApplicationforLegalEntity()
    *  This procedure gets the Application and Licenses jobs related to the top level legal entity.
    *-------------------------------------------------------------------------*/
    PROCEDURE applicationforlegalentity(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist);

    --*------------------------------------------------------------------------------------------------
    --* GetLEParent() -- Public
    --* Return the Parent of Legal Entity
    --*------------------------------------------------------------------------------------------------
    FUNCTION getleparent(a_objectid udt_id)
        RETURN udt_id;

    --*------------------------------------------------------------------------------------------------
    --* GetTopMostLEParent() -- Public
    --* Return the Top Most Parent of Legal Entity
    --*------------------------------------------------------------------------------------------------
    FUNCTION gettopmostleparent(a_objectid udt_id)
        RETURN udt_id;

    /*
      Access to Root Legal Entity
    */
    FUNCTION getrootlegalentity(a_objectid udt_id)
        RETURN udt_id;

    --*------------------------------------------------------------------------------------------------
    --* GetAppOrLicForLE() -- PUBLIC
    --* Find the application or license with which the legal entity is associated.
    --* Used for procedural relationship on Legal Entity to License, Application
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getappforle(a_objectid         udt_id,
                          a_endpointid       udt_id,
                          a_relatedobjectids OUT api.udt_objectlist);

    PROCEDURE getlicforle(a_objectid         udt_id,
                          a_endpointid       udt_id,
                          a_relatedobjectids OUT api.udt_objectlist);

    -------------------------------------------------------------------------------
    -- * LegalEntityCopy() -- PUBLIC
    -- Existing Legal Entities are copied for use on applications and licenses.
    -- Copy Legal Entity and all its relationships to a new legal entity.
    -- used by PKG_ISSUELICENSE.IssueOriginalLicense
    -- *---------------------------------------------------------------------------
    FUNCTION legalentitycopy(a_objectid      udt_id,
                             a_isp12acopy    BOOLEAN DEFAULT FALSE,
                             a_maintain      BOOLEAN DEFAULT FALSE)
        RETURN udt_id;

    FUNCTION legalentitycopy(a_objectid            udt_id,
                             a_p12amasterlicense   OUT NUMBER,
                             a_p12amasterleidold   OUT NUMBER,
                             a_p12aarray    IN OUT udt_p12alist,
                             a_isp12acopy          BOOLEAN DEFAULT FALSE,
                             a_maintain            BOOLEAN DEFAULT FALSE)
        RETURN udt_id;

    /*---------------------------------------------------------------------------
   * LegalEntityLookupCopy() -- PUBLIC
   *-------------------------------------------------------------------------*/
    PROCEDURE legalentitylookupcopy(a_relationshipid udt_id,
                                    a_asofdate      DATE,
                                    a_relationshipdefname VARCHAR2,
                                    a_endpointname  VARCHAR2);

    /*---------------------------------------------------------------------------
    * LegalEntityLookupCopy() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE legalentitylookupcopy(a_relationshipid      udt_id,
                                    a_asofdate            DATE,
                                    a_p12amasterlicense   OUT NUMBER,
                                    a_p12amasterleidold   OUT NUMBER,
                                    a_p12aarray    IN OUT udt_p12alist,
                                    a_relationshipdefname VARCHAR2,
                                    a_endpointname        VARCHAR2);

    PROCEDURE lecopy(a_relationshipid udt_id,
                     a_copyleobjid   udt_id,
                     a_copytoleobjid udt_id,
                     a_endpointid    udt_id,
                     a_lookup        BOOLEAN DEFAULT FALSE);

    /*---------------------------------------------------------------------------
    * LELookUpCopy() -- PUBLIC
    * This is run on construction of the LEParentChildCopy Relationship
    * rel to copy over a lookuped LE structure to a new licensee
    *-------------------------------------------------------------------------*/
    PROCEDURE lelookupcopy(a_relationshipid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * LegalEntityLookupDelete() - PUBLIC
     *  This procedure is used to return the relationship to delete when a a Legal
     *  Entity is removed from an Application or License.
     *-------------------------------------------------------------------------*/
    FUNCTION legalentitylookupdelete(a_jobid udt_id, a_rowobjectid udt_id)
        RETURN udt_id;

    /*********************************************************
    * Procedure LEStructureCopyNew()
    * This is used to copy existing legal entity structure to
    * a new application or license, but it does not work with
    * any of the P12 structure.
    * Created by: Daniel Magill
    * Created Date: 10/22/2015
    **********************************************************/
    PROCEDURE lestructurecopynew(a_relationshipid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
      * P12ALookupCopy() -- PUBLIC
      * This is run on construction of the P12AStockholderParentCopy Relationship
      * rel to copy over a lookuped P12A to a new license
      *-------------------------------------------------------------------------*/
    PROCEDURE p12alookupcopy(a_relationshipid udt_id, a_asofdate DATE);

    /*-----------------------------------------------------------------------
     * P12ACopy() -- Public
     * P12A is a new wrapper for the LegalEntityCopy Procedure
     * P12ACopy runs when lookup P12A is used
     * P12ACopy runs when a change is made to the P12A structure
     *------------------------------------------------------------------------*/
    PROCEDURE p12acopy(a_relationshipid udt_id,
                       a_copyleobjid   udt_id,
                       a_copytoleobjid udt_id,
                       a_endpointid    udt_id,
                       a_lookup        BOOLEAN DEFAULT FALSE,
                       a_maintain      BOOLEAN DEFAULT FALSE);

    --*------------------------------------------------------------------------------------------------
    --* GetP12AppOrLicForLE() -- PUBLIC
    --* Find the P12 Applications or non-master Licenses with which the legal entity is associated.
    --* Used for procedural relationship on Legal Entity to License, Application
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getp12appforle(a_objectid         udt_id,
                             a_endpointid       udt_id,
                             a_relatedobjectids OUT api.udt_objectlist);

    PROCEDURE getp12licforle(a_objectid         udt_id,
                             a_endpointid       udt_id,
                             a_relatedobjectids OUT api.udt_objectlist);

    /*---------------------------------------------------------------------------
     * LRAuditDestructor() -- PUBLIC
     *   Attach this to the Destructor of an Legal Entity
     *   Created because LEs are procedurally deleted and thus their columns couldn't be checked on deletion.
     *-------------------------------------------------------------------------*/
    PROCEDURE leauditdestructor(a_objectid      udt_id,
                                a_asofdate      DATE,
                                a_auditcolumns  VARCHAR2,
                                a_auditrelationshipnames VARCHAR2,
                                a_omitprefix    VARCHAR2 DEFAULT NULL);

    /*------------------------------
    -- LogNameChange ()
    -- This will run as a deferred procedure on change
    --  of the dup_FormattedName column on the Legal Entity.
    -- This will update the dup column on related Licenses/Applications.
    */
    ------------------------------
    PROCEDURE lognamechange(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
      * MarkForDeletion() - PUBLIC
      *  This procedure is used on deletion of the stored relationships between the
      *  Legal Entity and an Application or License respectively. It is used by
      *  sitespecific.pkg_Schedule.CleanLegalEntities to remove orphaned Legal Entities.
      *-------------------------------------------------------------------------*/
    PROCEDURE markfordeletion(a_relationshipid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * AddOfficerStockolderInfo() -- PUBLIC
     * When a new officer or stockholder information is filled in, the appropriate
     * relationships for officers, stockholders, persons and spouses
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE addofficerstockolderinfo(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * CopySpouse() -- PUBLIC
     * When a spouse is found through a lookup, a temporary relationship is created
     * and this process will take that temp relationship and create a new legal entity
     * and appropriate spouse and person relationships since a spouse can only be connected
     * through a spouse relationship between two legal entities
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE copyspouse(a_relationshipid udt_id, a_asofdate DATE);

    FUNCTION getlicorappforle(a_leobjid NUMBER)
        RETURN NUMBER;

    /*---------------------------------------------------------------------------
     * DeleteSpouse() -- PUBLIC
     * This procedure removes any relationships to a spouse from the legal entity
     * There may be several types of relationships: temp, spouse1 or in the case
     * of adding a legal entity to an existing entity, a person object id
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE deletespouse(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * DeletePerson() -- PUBLIC
     * This procedure removes any person and associated spouses from the legal entity
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE deleteperson(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * DeleteCompany() -- PUBLIC
     * This procedure removes any company from the legal entity
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------*/
    PROCEDURE deletecompany(a_objectid udt_id, a_asofdate DATE);

    /*--------------------------------------------------------------------------------------------
     * DeleteCompany() -- PUBLIC
     * This procedure fires on the legal entity post verify.  If this legal entity is
     * adding an officer and/or shareholder the AddOfficerStockholderInfo procedure will be called
     * Created by: Yars Tsaytak
     * Created Date: 10/23/15
     *-------------------------------------------------------------------------------------------*/
    PROCEDURE lepostverify(a_objectid udt_id, a_asofdate DATE);

    /*--------------------------------------------------------------------------------------------
     * CopyLegalEntity()
     * This function will copy all relationships and details from one legal entity to another
     * Created by: Yars Tsaytak
     * Created Date: 11/4/15
     *-------------------------------------------------------------------------------------------*/
    PROCEDURE copylegalentity(a_fromobjectid udt_id, a_toobjectid udt_id);

    /*--------------------------------------------------------------------------------------------
     * FromObjectIdColumnChange()
     * This function will make the root of the FromObjectId the root of the calling-object
     * Created by: Michael Froese
     * Created Date: 9/23/2016
     *-------------------------------------------------------------------------------------------*/
    PROCEDURE fromobjectidcolumnchange(a_objectid udt_id, a_asofdate DATE);
END pkg_legalentity;

/


GRANT EXECUTE ON SITESPECIFIC.PKG_LEGALENTITY TO POSSEEXTENSIONS;

GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_LEGALENTITY TO PSERVERSYS;

GRANT EXECUTE ON SITESPECIFIC.PKG_LEGALENTITY TO TOOLBOX;
