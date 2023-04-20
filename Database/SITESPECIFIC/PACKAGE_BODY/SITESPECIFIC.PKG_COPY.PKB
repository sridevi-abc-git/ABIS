CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_COPY"
IS
    -- **************************************************************************
    -- File:        PKG_COPY.PKB
    -- Author:      LOREN
    --
    -- $Rev: 380 $
    -- $Date: 2019-11-08 16:15:13 -0800 (Fri, 08 Nov 2019) $
    -- Last Changed By:  $Author: PKaur $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- 11/08/2019 PK          Made changes to increase performance of priority applications
    -- **************************************************************************

    ----------------------------------------------------------------------------------------------------
    --  CopyStoredObjectDetails() -- PUBLIC
    -- Copy stored details from one object to another, where the column names are the same.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE copystoredobjectdetails(a_fromobjectid  udt_id,
                                      a_toobjectid    udt_id)
    IS
    BEGIN
        FOR c
            IN (SELECT cd1.name
                  FROM api.columndefs  cd1
                       JOIN api.objects obj
                           ON obj.objectdefid = cd1.objectdefid
                       JOIN api.columndefs cd2 ON cd1.name = cd2.name
                       JOIN api.objects obj2
                           ON obj2.objectdefid = cd2.objectdefid
                 WHERE cd1.stored = 'Y'
                   AND cd2.stored = 'Y'
                   AND obj.objectid = a_fromobjectid
                   AND obj2.objectid = a_toobjectid)
        LOOP
            api.pkg_columnupdate.setvalue(
                a_toobjectid,
                c.name,
                api.pkg_columnquery.VALUE(a_fromobjectid, c.name));
        END LOOP;
    END;

    ----------------------------------------------------------------------------------------------------
    --  CopyStoredObjDetailsException() -- PUBLIC
    -- Copy stored details from one object to another, where the column names are the same. This allows
    -- the user to add an exception for a detail that should not be copied.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE copystoredobjdetailsexception(a_fromobjectid  udt_id,
                                            a_toobjectid    udt_id,
                                            a_exception     VARCHAR2)
    IS
        t_exception   extension.udst_stringlist;
    BEGIN
        t_exception   := extension.pkg_utils.splitcastable(a_exception, ',');

        FOR c
            IN (SELECT cd1.name
                  FROM api.columndefs  cd1
                       JOIN api.objects obj
                           ON obj.objectdefid = cd1.objectdefid
                       JOIN api.columndefs cd2 ON cd1.name = cd2.name
                       JOIN api.objects obj2
                           ON obj2.objectdefid = cd2.objectdefid
                 WHERE cd1.stored = 'Y'
                   AND cd2.stored = 'Y'
                   AND obj.objectid = a_fromobjectid
                   AND obj2.objectid = a_toobjectid
                   AND cd1.name NOT IN
                           (SELECT COLUMN_VALUE
                              FROM TABLE(
                                       CAST(
                                           t_exception AS extension.udst_stringlist))))
        LOOP
            api.pkg_columnupdate.setvalue(
                a_toobjectid,
                c.name,
                api.pkg_columnquery.VALUE(a_fromobjectid, c.name));
        END LOOP;
    END;


    ----------------------------------------------------------------------------------------------------
    --  RemoveNonUpgradePLTs() -- PUBLIC
    --  This also the rel to the PLTs that are not marked for upgrade on a Priority Application
    ----------------------------------------------------------------------------------------------------

    PROCEDURE removenonupgradeplts(a_objectid      udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id)
    IS
    BEGIN
        FOR x
            IN (SELECT aplt.relationshipid
                  FROM query.r_appprimarylicensetype  aplt
                       JOIN query.o_primarylicensetype plt
                           ON plt.objectid = aplt.licensetypeobjectid
                 WHERE aplt.applicationobjectid = a_jobid
                   AND plt.upgradethislt = 'N'
                    AND plt.licensetypecode = --OR plt.licensetypecode changed OR to AND as that is what logic should be and performance was really bad with OR -- By Pawan on 11/08/2019
                       (SELECT plt2.licensetypecode
                          FROM query.r_priorityprimarylicensetype  p
                               JOIN query.o_primarylicensetype plt2
                                   ON plt2.objectid =
                                      p.priorityprilicensetypeobjectid
                         WHERE p.applicationjobid = a_jobid))
        LOOP
            api.pkg_relationshipupdate.remove(x.relationshipid);
        END LOOP;
    END removenonupgradeplts;

    ----------------------------------------------------------------------------------------------------
    --  CopyPriorityLicenseTypes() -- PUBLIC
    --  This will copy the Priority License Type rels to the normal rels
    --  This also deletes the rel to the PLTs that are not marked for upgrade
    ----------------------------------------------------------------------------------------------------

    PROCEDURE copyprioritylicensetyperels(a_objectid      udt_id,
                                          a_asofdate      DATE,
                                          a_jobid         udt_id)
    IS
        t_relid   udt_id;
    BEGIN
        FOR c
            IN (SELECT o.objectid plt, ltc.objectid ltc
                  FROM api.relationships  r
                       JOIN api.objects o ON o.objectid = r.toobjectid
                       JOIN api.relationships r2
                           ON r2.fromobjectid = o.objectid
                       JOIN api.objects ltc ON ltc.objectid = r2.toobjectid
                 WHERE o.objectdefid =
                       api.pkg_configquery.objectdefidforname(
                           'o_PrimaryLicenseType')
                   AND r.fromobjectid = a_jobid
                   AND r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_Application',
                           'PriorityPriLicenseType')
                   AND r2.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'o_PrimaryLicenseType',
                           'LicTypeCatPriority')
                   AND api.pkg_columnquery.numericvalue(
                           o.objectid,
                           'PriorityLicenseTypeCode') NOT IN
                           (SELECT plt.licensetypecode
                              FROM query.r_appprimarylicensetype  aplt
                                   JOIN query.o_primarylicensetype plt
                                       ON aplt.licensetypeobjectid =
                                          plt.objectid
                             WHERE aplt.applicationobjectid = a_jobid))
        LOOP
            t_relid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname(
                        'j_Application',
                        'PrimaryLicenseType'),
                    a_jobid,
                    c.plt);

            t_relid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname(
                        'o_PrimaryLicenseType',
                        'LicTypeCatPrimary'),
                    c.plt,
                    c.ltc);
        END LOOP;
    END copyprioritylicensetyperels;

    ----------------------------------------------------------------------------------------------------
    --  CopyUpgradeRelationship() -- PUBLIC
    --  This will copy the Upgrading from License to either the License Transferring From rel or
    --   the License rel.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE copyupgraderelationship(a_objectid udt_id, a_asofdate DATE)
    IS
        t_priorityupgrade           query.j_application.priorityupgrade%TYPE;
        t_priorityapplicationtype   query.j_application.priorityapplicationtype%TYPE;
        t_relid                     udt_id;
        t_licobjid                  udt_id;
    BEGIN
        t_priorityupgrade   :=
            api.pkg_columnquery.VALUE(a_objectid, 'PriorityUpgrade');
        t_priorityapplicationtype   :=
            api.pkg_columnquery.VALUE(a_objectid, 'PriorityApplicationType');

        BEGIN
            SELECT toobjectid
              INTO t_licobjid
              FROM api.relationships
             WHERE fromobjectid = a_objectid
               AND endpointid =
                   api.pkg_configquery.endpointidforname('j_Application',
                                                         'LicenseUpgrade');

            IF t_priorityapplicationtype = 'Intercounty Transfer' THEN
                BEGIN
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'LicenseTransfer'),
                            a_objectid,
                            t_licobjid);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                               'ERROR determining License being Upgraded. '
                            || SQLERRM);
                END;
            ELSIF t_priorityupgrade = 'Yes'
              AND t_priorityapplicationtype = 'Original' THEN
                BEGIN
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'License'),
                            a_objectid,
                            t_licobjid);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                               'ERROR determining License being Upgraded. '
                            || SQLERRM);
                END;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_relid   := NULL;
        END;
    END copyupgraderelationship;

    ----------------------------------------------------------------------------------------------------
    --  CopyUpgradeRelationship() -- PUBLIC
    --  This will copy the Status from the Primary License Type on to the realtionship
    --  between the primary and the catagory, run on contructor of the relationship and on
    --  status change
    ----------------------------------------------------------------------------------------------------

    PROCEDURE copyprimarylicensetypestatus(a_objectid      udt_id,
                                           a_asofdate      DATE)
    IS
        t_status           VARCHAR2(60);
        t_relationshipid   udt_id;
    BEGIN
        SELECT plt.status, r.relationshipid
          INTO t_status, t_relationshipid
          FROM query.r_priltltcatprimary  r
               JOIN query.o_primarylicensetype plt
                   ON plt.objectid = r.primarylicensetypeobjectid
         WHERE plt.objectid = a_objectid
            OR r.relationshipid = a_objectid;

        api.pkg_columnupdate.setvalue(t_relationshipid,
                                      'PrimaryLicenseTypeStatus',
                                      t_status);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END copyprimarylicensetypestatus;
END pkg_copy;
/
