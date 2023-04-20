CREATE OR REPLACE PROCEDURE ABC.bcp_statewideactivelic_536(p_reportdate DATE)
AS
    -- **************************************************************************
    -- File:        BCP_STATEWIDEACTIVELIC_536.PRC
    -- Author:      Sheik Sulthan
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- IMPORTANT NOTE:
    --      When using query errors out then use this procedure to extract active
    --      licenses data (by Infomaker report ABC-536 query logic)
    --
    -- PURPOSE:    Statewide Active licenses with Gallonage and population code for Randy's BCP
    --
    -- Use parameters:
    -- A_DEBUG   - Y/N (Yes means will display dynamic messages in the output
    --                      window(DBMS_OUTPUT) and No means suppresses all output messages)
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 07/26/2018             Statewide Active licenses with Gallonage and population
    --                          code for Randy's BCP
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    -- define array type of the new table
    TYPE act_lic_t IS TABLE OF abc.bcp_activelicenses_536%ROWTYPE
        INDEX BY BINARY_INTEGER;

    -- define array object of new table
    l_act_lic   act_lic_t;


    c_limit     PLS_INTEGER := 50;

    CURSOR act_lic_cur
    IS
        SELECT 'PRIMARY'
                   isprimary,
               lt.licensenumber
                   licensenumber,
               jlt.masterlicensenumber,
               ltc.licensetypecode
                   licensetype,
               ltc.licensetypename
                   licensetypename,
               (SELECT DISTINCT o.populationapplies
                  FROM query.o_licensetypecategory o
                 WHERE licensetypecode = lt.licensetypecode)
                   populationapplies,
               jlt.gallonagerangefeecode,
               jlt.populationrangefeecode,
               lt.statusdescription,
               r.licensetypecount
          FROM mart.licensetype  lt
               JOIN query.j_licensetype jlt ON jlt.objectid = lt.objectid
               JOIN mart.primaryandsecondarylicencetype r
                   ON r.licensetypeobjectid = lt.objectid
               JOIN mart.licensetypecategory ltc
                   ON r.licensecetypecategoryobjectid = ltc.objectid
               JOIN extension.jobstatuschange j ON lt.objectid = j.jobid
         WHERE r.primary IS NOT NULL
           AND j.statusname IN ('ACTIVE',
                                'SUREND',
                                'SUSPEN',
                                'R64B',
                                'SLMSHD',
                                'REVPEN')
           AND j.effectivestartdate =
               (SELECT MAX(jo.effectivestartdate)
                  FROM extension.jobstatuschange jo
                 WHERE jo.effectivestartdate < p_reportdate
                   AND jo.jobid = j.jobid)
        UNION ALL
        SELECT 'DUP'
                   isprimary,
               lt2.licensenumber,
               jlt.masterlicensenumber,
               ltc2.licensetypecode
                   licensetype,
               'DUP - ' || ltc2.licensetypename
                   licensetypename,
               (SELECT o.populationapplies
                  FROM query.o_licensetypecategory o
                 WHERE licensetypecode = lt2.licensetypecode)
                   populationapplies,
               jlt.gallonagerangefeecode,
               jlt.populationrangefeecode,
               x.status,
               x.licensetypecount
          FROM mart.licensetype  lt2                                 --primary
               JOIN query.j_licensetype jlt ON jlt.objectid = lt2.objectid
               JOIN mart.primaryandsecondarylicencetype x
                   ON x.licensetypeobjectid = lt2.objectid
               JOIN sitespecific.sltstatuschange_t sc
                   ON sc.relationshipid = x.relationshipid
               JOIN mart.licensetypecategory ltc2
                   ON ltc2.objectid = x.licensecetypecategoryobjectid
               JOIN mart.licensetypecategoryrel plt
                   ON plt.licensetypeobjectid = lt2.objectid
         WHERE x.primary IS NULL                        --secondary lt's only.
           AND sc.statusname IN ('ACTIVE',
                                 'SUREND',
                                 'SUSPEN',
                                 'R64B',
                                 'SLSMSHD',
                                 'REVPEN')
           AND sc.effectivestartdate =
               (SELECT MAX(sc2.effectivestartdate)
                  FROM sitespecific.sltstatuschange_t sc2
                 WHERE sc2.relationshipid = x.relationshipid
                   AND sc2.effectivestartdate < p_reportdate);
BEGIN
    dbms_output.put_line('Starting... ');

    DELETE FROM abc.bcp_activelicenses_536;

    COMMIT;


    OPEN act_lic_cur;

    LOOP
        FETCH act_lic_cur BULK COLLECT INTO l_act_lic LIMIT c_limit;

        EXIT WHEN act_lic_cur%NOTFOUND;

        FORALL i IN INDICES OF l_act_lic SAVE EXCEPTIONS
            INSERT INTO abc.bcp_activelicenses_536
            VALUES l_act_lic(i);

        COMMIT;
    END LOOP;

    CLOSE act_lic_cur;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('Error no_data_found ');
        dbms_output.put_line(SQLCODE || SQLERRM);
    WHEN TOO_MANY_ROWS THEN
        dbms_output.put_line('TOO_MANY_ROWS');
        dbms_output.put_line(SQLCODE || SQLERRM);
    WHEN VALUE_ERROR THEN
        dbms_output.put_line('VALUE_ERROR');
        dbms_output.put_line(SQLCODE || SQLERRM);
END bcp_statewideactivelic_536;
/
