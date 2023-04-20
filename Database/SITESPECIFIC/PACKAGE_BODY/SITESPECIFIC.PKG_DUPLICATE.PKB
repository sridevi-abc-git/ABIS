CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_duplicate
IS
    -- **************************************************************************
    -- File:        PKG_DUPLICATE.pkb
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

    ---------------------------------------------------------
    --  CreateDuplicateRows() -- PUBLIC
    --  This procedures runs on Column change of the New Count column and creates the duplicate rows.
    ---------------------------------------------------------
    PROCEDURE createduplicaterows(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_newcount      NUMBER)
    IS
        t_temp1                         VARCHAR2(100);
        t_newobjectid                   udt_id;
        t_dupdefid                      udt_id;
        t_licensetypecategoryobjectid   udt_id;
        t_licensetypejobid              udt_id;
        t_primarylicensetypeobjectid    udt_id;
        t_currentcount                  NUMBER;
        t_newcount                      NUMBER;
    BEGIN
        t_dupdefid   := api.pkg_configquery.objectdefidforname('o_Duplicate');
        t_licensetypecategoryobjectid   :=
            api.pkg_columnquery.VALUE(a_objectid, 'LTCObjectID');
        t_licensetypejobid   :=
            api.pkg_columnquery.VALUE(a_objectid, 'LTJobID');
        t_primarylicensetypeobjectid   :=
            api.pkg_columnquery.VALUE(a_objectid, 'PLTObjectID');
        t_currentcount   :=
            api.pkg_columnquery.VALUE(a_objectid, 'LicenseTypeCount');
        t_newcount   :=
            CASE WHEN a_newcount = 0 THEN 1 ELSE NVL(a_newcount, 1) END;

        IF NVL(t_currentcount, 1) > NVL(t_newcount, 1) THEN
            api.pkg_errors.raiseerror(
                -20001,
                'The New Count must be equal or greater than the Current Count.');
        END IF;

        FOR c IN (SELECT slt.relationshipid,
                         slt.licensetypejobid,
                         slt.licensetypecategoryobjectid,
                         NULL                 description,
                         slt.readytoissuedate readytoissuedate,
                         NULL                 PRINT,
                         NULL                 issuedate,
                         slt.typeofissuance   typeofissuance,
                         NULL                 primarylicensetypeobjectid
                    FROM query.r_licensetypeltcatsecondary  slt
                         CROSS JOIN TABLE(sitespecific.pkg_utils.generaterows(
                                              NVL(
                                                  (SELECT   MAX(od.dupnumber)
                                                          + 1
                                                     FROM sitespecific.duplicate_t
                                                          d
                                                          JOIN
                                                          query.o_duplicate
                                                          od
                                                              ON od.objectid =
                                                                 d.duplicateid
                                                    WHERE d.relationshipid =
                                                          a_objectid),
                                                  1),
                                              t_newcount)) x
                   WHERE slt.relationshipid = a_objectid
                  UNION ALL
                  SELECT slt.relationshipid,
                         splt.licensetypejobid,
                         splt.licensetypecategoryobjectid,
                         NULL description,
                         NULL readytoissuedate,
                         NULL PRINT,
                         NULL issuedate,
                         NULL typeofissuance,
                         NULL primarylicensetypeobjectid
                    FROM query.r_licensetypependsecltcat  splt
                         LEFT OUTER JOIN
                         query.r_licensetypeltcatsecondary slt
                             ON slt.licensetypejobid = splt.licensetypejobid
                            AND slt.licensetypecategoryobjectid =
                                splt.licensetypecategoryobjectid
                         CROSS JOIN TABLE(sitespecific.pkg_utils.generaterows(
                                              NVL(
                                                  (SELECT   MAX(od.dupnumber)
                                                          + 1
                                                     FROM sitespecific.duplicate_t
                                                          d
                                                          JOIN
                                                          query.o_duplicate
                                                          od
                                                              ON od.objectid =
                                                                 d.duplicateid
                                                    WHERE d.licensetypejobid =
                                                          t_licensetypejobid
                                                      AND d.licensetypecategoryobjectid =
                                                          t_licensetypecategoryobjectid),
                                                  1),
                                              t_newcount)) x
                   WHERE splt.relationshipid = a_objectid
                  UNION ALL
                  SELECT splt.relationshipid,
                         NULL licensetypejobid,
                         splt.licensetypecategoryobjectid,
                         NULL description,
                         NULL readytoissuedate,
                         NULL PRINT,
                         NULL issuedate,
                         NULL typeofissuance,
                         splt.primarylicensetypeobjectid
                    FROM query.r_priltltcatsecondary  splt
                         CROSS JOIN TABLE(sitespecific.pkg_utils.generaterows(
                                              NVL(
                                                  (SELECT   MAX(od.dupnumber)
                                                          + 1
                                                     FROM sitespecific.duplicate_t
                                                          d
                                                          JOIN
                                                          query.o_duplicate
                                                          od
                                                              ON od.objectid =
                                                                 d.duplicateid
                                                    WHERE d.primarylicensetypeobjectid =
                                                          t_primarylicensetypeobjectid
                                                      AND d.licensetypecategoryobjectid =
                                                          t_licensetypecategoryobjectid),
                                                  1),
                                              t_newcount)) x
                   WHERE splt.relationshipid = a_objectid)
        LOOP
            --Create new object
            t_newobjectid   := api.pkg_objectupdate.new(t_dupdefid);
            --set columns for new object
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'RelationshipID',
                                          c.relationshipid);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'LicenseTypeJobId',
                                          c.licensetypejobid);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'LicenseTypeCategoryObjectId',
                                          c.licensetypecategoryobjectid);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'PrimaryLicenseTypeObjectID',
                                          c.primarylicensetypeobjectid);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'Description',
                                          c.description);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'ReadyToIssueDate',
                                          c.readytoissuedate);
            api.pkg_columnupdate.setvalue(t_newobjectid, 'Print', c.PRINT);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'IssueDate',
                                          c.issuedate);
            api.pkg_columnupdate.setvalue(t_newobjectid,
                                          'TypeOfIssuance',
                                          c.typeofissuance);
        END LOOP;
    END createduplicaterows;

    /*-------------------------------------------------------------------------------
    * Procedure CreateDuplicate()  Used on creation of o_Duplicate.
    *-----------------------------------------------------------------------------*/

    PROCEDURE createduplicate(a_objectid     IN OUT NUMBER,
                              a_relationshipid      NUMBER,
                              a_licensetypejobid    NUMBER,
                              a_licensetypecategoryobjectid NUMBER,
                              a_description         VARCHAR2,
                              a_readytoissuedate    DATE,
                              a_print               VARCHAR2 DEFAULT 'N',
                              a_issuedate           DATE,
                              a_typeofissuance      VARCHAR2,
                              a_primarylicensetypeobjectid NUMBER)
    IS
        t_objid   NUMBER(9);
    BEGIN
        INSERT INTO sitespecific.duplicate_t(duplicateid,
                                             relationshipid,
                                             licensetypejobid,
                                             licensetypecategoryobjectid,
                                             description,
                                             readytoissuedate,
                                             PRINT,
                                             issuedate,
                                             typeofissuance,
                                             primarylicensetypeobjectid)
             VALUES (a_objectid,
                     a_relationshipid,
                     a_licensetypejobid,
                     a_licensetypecategoryobjectid,
                     a_description,
                     a_readytoissuedate,
                     NVL(a_print, 'N'),
                     a_issuedate,
                     a_typeofissuance,
                     a_primarylicensetypeobjectid);
    END createduplicate;

    /*-------------------------------------------------------------------------------
    * Procedure ModifyDuplicate()  Used on modification of o_Duplicate.
    *-----------------------------------------------------------------------------*/

    PROCEDURE modifyduplicate(a_objectid     IN OUT NUMBER,
                              a_relationshipid      NUMBER,
                              a_licensetypejobid    NUMBER,
                              a_licensetypecategoryobjectid NUMBER,
                              a_description         VARCHAR2,
                              a_readytoissuedate    DATE,
                              a_print               VARCHAR2 DEFAULT 'N',
                              a_issuedate           DATE,
                              a_typeofissuance      VARCHAR2,
                              a_primarylicensetypeobjectid NUMBER)
    IS
        t_surchargecount   NUMBER;
        t_ltcount          NUMBER;
    BEGIN
        UPDATE sitespecific.duplicate_t t
           SET relationshipid                = a_relationshipid,
               licensetypejobid              = a_licensetypejobid,
               licensetypecategoryobjectid   = a_licensetypecategoryobjectid,
               description                   = a_description,
               readytoissuedate              = a_readytoissuedate,
               PRINT                         = NVL(a_print, 'N'),
               issuedate                     = a_issuedate,
               typeofissuance                = a_typeofissuance,
               primarylicensetypeobjectid    = a_primarylicensetypeobjectid
         WHERE t.duplicateid = a_objectid;
    END modifyduplicate;

    /*-------------------------------------------------------------------------------
    * Procedure CascadeDuplicateDelete() used on destructor of the relationships to remove externally related duplicate objects.
    *------------------------------------------------------------------------------*/

    PROCEDURE cascadeduplicatedelete(a_objectid udt_id, a_asofdate DATE)
    IS
        t_ltcdefid   udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_LicenseTypeCategory');
    BEGIN
        --loop through related duplicates
        FOR d
            IN (SELECT d.duplicateid objectid
                  FROM api.relationships  r
                       JOIN api.endpoints ep ON ep.endpointid = r.endpointid
                       JOIN sitespecific.duplicate_t d
                           ON d.licensetypecategoryobjectid = r.toobjectid
                          AND (d.licensetypejobid = r.fromobjectid
                            OR d.primarylicensetypeobjectid = r.fromobjectid)
                 WHERE r.relationshipid = a_objectid
                   AND ep.toobjectdefid = t_ltcdefid)
        LOOP
            api.pkg_objectupdate.remove(d.objectid, SYSDATE);
        END LOOP;
    END;
END pkg_duplicate;
/
