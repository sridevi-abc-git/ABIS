CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_proceduralrelsample
AS
    -- **************************************************************************
    -- File:        PKG_PROCEDURALRELSAMPLE.PKB
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
     * Sample() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE primaryltstatuses(a_objectid         udt_id,
                                a_endpointid       udt_id,
                                a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_apprecords   api.udt_objectlist;
        t_licrecords   api.udt_objectlist;
    BEGIN
        t_apprecords         := api.udt_objectlist();
        t_licrecords         := api.udt_objectlist();
        a_relatedobjectids   := api.udt_objectlist();

        --a_ObjectId is a LICENSE
        --for status change history for both license and application types (Primary) for License Job (Status Change Tab in default presentation)
        FOR x IN (SELECT r.licensetypejobid
                    FROM query.r_licenselicensetype r
                   WHERE r.licensejobid = a_objectid)
        LOOP
            t_licrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_PrimaryLTStatusHistory',
                    'JOBID',
                    x.licensetypejobid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_licrecords);
        END LOOP;

        FOR y
            IN (SELECT p.licensetypeobjectid
                  FROM query.r_applicationlicense  r
                       JOIN query.r_appprimarylicensetype p
                           ON p.applicationobjectid = r.applicationjobid
                 WHERE r.licensejobid = a_objectid)
        LOOP
            t_apprecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_PrimaryLTStatusHistory',
                    'JOBID',
                    y.licensetypeobjectid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_apprecords);
        END LOOP;
    END;

    PROCEDURE secondaryltstatuses(a_objectid         udt_id,
                                  a_endpointid       udt_id,
                                  a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_apprecords          api.udt_objectlist;
        t_licrecords          api.udt_objectlist;
        t_sltremovedrecords   api.udt_objectlist;
    BEGIN
        t_apprecords          := api.udt_objectlist();
        t_licrecords          := api.udt_objectlist();
        t_sltremovedrecords   := api.udt_objectlist();
        a_relatedobjectids    := api.udt_objectlist();

        --a_ObjectId is a LICENSE
        --for status change history for both license and application types (Secondary) for License Job (Status Change Tab in default presentation)
        FOR x
            IN (SELECT s.relationshipid
                  FROM query.r_licenselicensetype  r
                       JOIN query.r_licensetypeltcatsecondary s
                           ON s.licensetypejobid = r.licensetypejobid
                 WHERE r.licensejobid = a_objectid)
        LOOP
            t_licrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    x.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_licrecords);
        END LOOP;

        FOR y
            IN (SELECT s.relationshipid
                  FROM query.r_applicationlicense  r
                       JOIN query.r_appprimarylicensetype p
                           ON p.applicationobjectid = r.applicationjobid
                       JOIN query.r_priltltcatsecondary s
                           ON s.primarylicensetypeobjectid =
                              p.licensetypeobjectid
                 WHERE r.licensejobid = a_objectid)
        LOOP
            t_apprecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    y.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_apprecords);
        END LOOP;

        FOR z
            IN (SELECT s.relationshipid
                  FROM query.r_licenselicensetype  r
                       JOIN sitespecific.sltstatuschange_t s
                           ON s.fromobjectid = r.licensetypejobid
                 WHERE r.licensejobid = a_objectid
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_licensetypeltcatsecondary ltslt
                             WHERE ltslt.relationshipid = s.relationshipid))
        LOOP
            t_sltremovedrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    z.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_sltremovedrecords);
        END LOOP;
    END;

    PROCEDURE appprimaryltstatuses(a_objectid         udt_id,
                                   a_endpointid       udt_id,
                                   a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_apprecords   api.udt_objectlist;
        t_licrecords   api.udt_objectlist;
    BEGIN
        t_apprecords         := api.udt_objectlist();
        t_licrecords         := api.udt_objectlist();
        a_relatedobjectids   := api.udt_objectlist();

        --a_ObjectId is a APPLICATION
        --for status change history for both license and application types (primary) for Applicaiton Job (Status Change Tab in default presentation)
        FOR x
            IN (SELECT lt.licensetypejobid
                  FROM query.r_applicationlicense  r
                       JOIN query.r_licenselicensetype lt
                           ON lt.licensejobid = r.licensejobid
                 WHERE r.applicationjobid = a_objectid)
        LOOP
            t_licrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_PrimaryLTStatusHistory',
                    'JOBID',
                    x.licensetypejobid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_licrecords);
        END LOOP;

        FOR y IN (SELECT r.licensetypeobjectid
                    FROM query.r_appprimarylicensetype r
                   WHERE r.applicationobjectid = a_objectid)
        LOOP
            t_apprecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_PrimaryLTStatusHistory',
                    'JOBID',
                    y.licensetypeobjectid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_apprecords);
        END LOOP;
    END appprimaryltstatuses;

    PROCEDURE appsecondaryltstatuses(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_apprecords             api.udt_objectlist;
        t_appremovedsltrecords   api.udt_objectlist;
        t_licrecords             api.udt_objectlist;
    BEGIN
        t_apprecords             := api.udt_objectlist();
        t_licrecords             := api.udt_objectlist();
        t_appremovedsltrecords   := api.udt_objectlist();
        a_relatedobjectids       := api.udt_objectlist();

        --a_ObjectId is a APPLICATION
        --for status change history for both license and application types (secondary) for Applicaiton Job (Status Change Tab in default presentation)
        FOR x
            IN (SELECT s.relationshipid
                  FROM query.r_applicationlicense  r
                       JOIN query.r_licenselicensetype lt
                           ON lt.licensejobid = r.licensejobid
                       JOIN query.r_licensetypeltcatsecondary s
                           ON s.licensetypejobid = lt.licensetypejobid
                 WHERE r.applicationjobid = a_objectid)
        LOOP
            t_licrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    x.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_licrecords);
        END LOOP;

        FOR y
            IN (SELECT s.relationshipid
                  FROM query.r_appprimarylicensetype  r
                       JOIN query.r_priltltcatsecondary s
                           ON s.primarylicensetypeobjectid =
                              r.licensetypeobjectid
                 WHERE r.applicationobjectid = a_objectid)
        LOOP
            t_apprecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    y.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_apprecords);
        END LOOP;

        FOR z
            IN (SELECT slt.relationshipid
                  FROM query.r_applicationlicense  r
                       JOIN query.r_licenselicensetype lt
                           ON lt.licensejobid = r.licensejobid
                       JOIN sitespecific.sltstatuschange_t slt
                           ON slt.fromobjectid = lt.licensetypejobid
                 WHERE r.applicationjobid = a_objectid
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_licensetypeltcatsecondary s
                             WHERE s.relationshipid = slt.relationshipid))
        LOOP
            t_appremovedsltrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    z.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_appremovedsltrecords);
        END LOOP;
    END appsecondaryltstatuses;

    PROCEDURE ltprimaryltstatuses(a_objectid         udt_id,
                                  a_endpointid       udt_id,
                                  a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_apprecords   api.udt_objectlist;
        t_licrecords   api.udt_objectlist;
    BEGIN
        t_apprecords         := api.udt_objectlist();
        t_licrecords         := api.udt_objectlist();
        a_relatedobjectids   := api.udt_objectlist();

        --a_ObjectId is a LICENSE TYPE
        --for status change history for both license and application types (Primary) for License Type Job (Status Change Tab in default presentation)
        FOR x
            IN (SELECT alllts.licensetypejobid
                  FROM query.r_licenselicensetype  r
                       JOIN query.r_licenselicensetype alllts
                           ON alllts.licensejobid = r.licensejobid
                 WHERE r.licensetypejobid = a_objectid)
        LOOP
            t_licrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_PrimaryLTStatusHistory',
                    'JOBID',
                    x.licensetypejobid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_licrecords);
        END LOOP;

        FOR y
            IN (SELECT p.licensetypeobjectid
                  FROM query.r_licenselicensetype  r
                       JOIN query.r_applicationlicense a
                           ON a.licensejobid = r.licensejobid
                       JOIN query.r_appprimarylicensetype p
                           ON p.applicationobjectid = a.applicationjobid
                 WHERE r.licensetypejobid = a_objectid)
        LOOP
            t_apprecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_PrimaryLTStatusHistory',
                    'JOBID',
                    y.licensetypeobjectid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_apprecords);
        END LOOP;
    END ltprimaryltstatuses;


    PROCEDURE ltsecondaryltstatuses(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_apprecords          api.udt_objectlist;
        t_licrecords          api.udt_objectlist;
        t_sltremovedrecords   api.udt_objectlist;
    BEGIN
        t_apprecords          := api.udt_objectlist();
        t_sltremovedrecords   := api.udt_objectlist();
        t_licrecords          := api.udt_objectlist();
        a_relatedobjectids    := api.udt_objectlist();

        --a_ObjectId is a LICENSE TYPE
        --for status change history for both license and application types (Secondary) for License Type Job (Status Change Tab in default presentation)
        FOR x
            IN (SELECT s.relationshipid
                  FROM query.r_licenselicensetype  r
                       JOIN query.r_licenselicensetype alllts
                           ON alllts.licensejobid = r.licensejobid
                       JOIN query.r_licensetypeltcatsecondary s
                           ON s.licensetypejobid = alllts.licensetypejobid
                 WHERE r.licensetypejobid = a_objectid)
        LOOP
            t_licrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    x.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_licrecords);
        END LOOP;

        FOR y
            IN (SELECT s.relationshipid
                  FROM query.r_licenselicensetype  r
                       JOIN query.r_applicationlicense a
                           ON a.licensejobid = r.licensejobid
                       JOIN query.r_appprimarylicensetype p
                           ON p.applicationobjectid = a.applicationjobid
                       JOIN query.r_priltltcatsecondary s
                           ON s.primarylicensetypeobjectid =
                              p.licensetypeobjectid
                 WHERE r.licensetypejobid = a_objectid)
        LOOP
            t_apprecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    y.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_apprecords);
        END LOOP;

        FOR z
            IN (SELECT slt.relationshipid
                  FROM query.r_licenselicensetype  r
                       JOIN query.r_licenselicensetype alllts
                           ON alllts.licensejobid = r.licensejobid
                       JOIN sitespecific.sltstatuschange_t slt
                           ON slt.fromobjectid = alllts.licensetypejobid
                 WHERE r.licensetypejobid = a_objectid
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_licensetypeltcatsecondary s
                             WHERE s.relationshipid = slt.relationshipid))
        LOOP
            t_sltremovedrecords   :=
                api.pkg_simplesearch.castableobjectsbyindex(
                    'o_SecondaryLTStatusHistory',
                    'RELATIONSHIPID',
                    z.relationshipid);
            extension.pkg_collectionutils.append(a_relatedobjectids,
                                                 t_sltremovedrecords);
        END LOOP;
    END ltsecondaryltstatuses;
END pkg_proceduralrelsample;
/
