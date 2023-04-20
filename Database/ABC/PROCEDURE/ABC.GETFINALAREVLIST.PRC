CREATE OR REPLACE PROCEDURE ABC."GETFINALAREVLIST"(
    -- **************************************************************************
    -- File:        GETFINALAREVLIST.PRC
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
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************
    /*  Final Auto-Revocation List (AREV - PART 2)
        Extracts License Type Information of those that have been revoked from a batch
    */
    a_objectid      api.pkg_definition.udt_id)
AS
    t_batchtype      query.j_licensebatch.batchtype%TYPE
                         := api.pkg_columnquery.VALUE(a_objectid, 'BatchType');
    t_expiredt       DATE;
    t_licensenum     query.j_license.licensenumber%TYPE;
    t_licjobid       api.pkg_definition.udt_id;
    t_licstatus      query.j_license.statusname%TYPE;
    t_ltcode         query.j_licensetype.licensetypecode%TYPE;
    t_ltstatus       extension.jobstatuschange_t.statusname%TYPE;
    t_ltstatusdt     DATE;
    t_premaddr2lns   query.j_licensetype.premaddress1line%TYPE;
    t_primlicensee   query.j_licensetype.primarylicensee%TYPE;
BEGIN
    DELETE FROM abc.arev;

    IF t_batchtype <> 'AUTO REVOKE LICENSE TYPES' THEN
        GOTO endarevlist;
    END IF;

    FOR arevrec IN (SELECT r.licensebatchjobid, r.licensetypejobid
                      FROM sitespecific.licbatchlictype_xref_t r
                     WHERE r.licensebatchjobid = a_objectid)
    LOOP
        t_expiredt   :=
            TO_DATE(
                api.pkg_columnquery.VALUE(arevrec.licensebatchjobid,
                                          'ExpirationDate'),
                'YYYY-MM-DD HH24:MI:SS');
        t_licensenum   :=
            api.pkg_columnquery.VALUE(arevrec.licensetypejobid,
                                      'LicenseNumber');
        t_licjobid   :=
            api.pkg_columnquery.VALUE(arevrec.licensetypejobid,
                                      'LicenseJobId');
        t_licstatus   :=
            api.pkg_columnquery.VALUE(
                api.pkg_columnquery.VALUE(arevrec.licensetypejobid,
                                          'LicenseJobId'),
                'StatusName');
        t_ltcode   :=
            api.pkg_columnquery.VALUE(arevrec.licensetypejobid,
                                      'LicenseTypeCode');
        t_premaddr2lns   :=
            api.pkg_columnquery.VALUE(arevrec.licensetypejobid,
                                      'LicensePremisesAddress2Lines');
        t_primlicensee   :=
            api.pkg_columnquery.VALUE(arevrec.licensetypejobid,
                                      'PrimaryLicensee');

        abc.get_status(arevrec.licensetypejobid, t_ltstatus, t_ltstatusdt);

        -- Primary License Types
        INSERT INTO abc.arev(batchtype,
                             btjobid,
                             expiredt,
                             licensenum,
                             licjobid,
                             licstatus,
                             ltcode,
                             ltjobid,
                             ltstatus,
                             ltstatusdt,
                             premaddr2lns,
                             primlicensee)
             VALUES (t_batchtype,
                     a_objectid,
                     t_expiredt,
                     t_licensenum,
                     t_licjobid,
                     t_licstatus,
                     t_ltcode,
                     arevrec.licensetypejobid,
                     t_ltstatus,
                     t_ltstatusdt,
                     t_premaddr2lns,
                     t_primlicensee);

        -- Secondary License Types
        INSERT INTO abc.arev(batchtype,
                             btjobid,
                             expiredt,
                             licensenum,
                             licjobid,
                             licstatus,
                             ltcode,
                             ltjobid,
                             ltstatus,
                             ltstatusdt,
                             premaddr2lns,
                             primlicensee,
                             sltobjid)
            SELECT t_batchtype                       batchtype,
                   a_objectid                        btjobid,
                   t_expiredt                        expiredt,
                   t_licensenum                      licensenum,
                   t_licjobid                        licjobid,
                   t_licstatus                       licstatus,
                   oltc.licensetypecode              ltcode,
                   arevrec.licensetypejobid          ltjobid,
                   NVL(slt.status, t_ltstatus)       ltstatus,
                   NVL(slt.statusdate, t_ltstatusdt) ltstatusdt,
                   t_premaddr2lns                    premaddr2lns,
                   t_primlicensee                    primlicensee,
                   slt.relationshipid                sltobjid
              FROM query.r_licensetypeltcatsecondary  slt
                   JOIN query.o_licensetypecategory oltc
                       ON oltc.objectid = slt.licensetypecategoryobjectid
             WHERE slt.licensetypejobid = arevrec.licensetypejobid;
    END LOOP;

   <<endarevlist>>
    NULL;

    COMMIT;

    --per Serena, delete all data exception autrev and auto revoked.  08/22/2011 Bee.
    DELETE FROM abc.arev av
          WHERE av.ltstatus NOT IN ('AUTREV', 'AUTO REVOKED');

    COMMIT;
END getfinalarevlist;
/


GRANT EXECUTE ON ABC.GETFINALAREVLIST TO POSSEEXTENSIONS;
