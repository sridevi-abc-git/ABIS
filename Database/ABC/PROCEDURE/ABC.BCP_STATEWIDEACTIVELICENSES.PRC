CREATE OR REPLACE PROCEDURE ABC.bcp_statewideactivelicenses
AS
    -- **************************************************************************
    -- File:        BCP_STATEWIDEACTIVELICENSES.PRC
    -- Author:      Sheik Sulthan
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- PURPOSE:    Statewide Active licenses with Gallonage and population code for Randy's BCP
    --
    -- Use parameters:
    -- A_DEBUG  - Y/N (Yes means will display dynamic messages in the output
    --                window(DBMS_OUTPUT) and No means suppresses all output messages)
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 07/17/2018 SS          Statewide Active licenses with Gallonage and population
    --                            code for Randy's BCP
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    -- define array type of the new table
    TYPE act_lic_t IS TABLE OF abc.bcp_activelicenses%ROWTYPE
        INDEX BY BINARY_INTEGER;

    -- define array object of new table
    l_act_lic   act_lic_t;


    c_limit     PLS_INTEGER := 50;

    CURSOR act_lic_cur
    IS
        SELECT jl.licensenumber,
               jlt.licensetypecode,
               jlt.masterltlicensenumber,
               (CASE
                    WHEN jlt.secondarylicensetypecode IS NOT NULL THEN
                        'MASTER'
                    ELSE
                        'SECONDARY'
                END)
                   masterlicensetype,
               jlt.dup_licensetypecode,
               jl.primarylicensetypecodes,
               jlt.secondarylicensetypecode,
               jlt.secondaryltcodewithcount,
               licensetypecodesandnumber,
               jlt.statusname,
               jlt.populationrangefeecode,
               jl.gallonagerange,
               jl.gallonagerangevaluecount,
               jlt.gallonagerangerule,
               jlt.gallonagerangefeecode,
               (SELECT DISTINCT o.populationapplies
                  FROM query.o_licensetypecategory o
                 WHERE licensetypecode = jlt.licensetypecode)
                   populationapplies
          FROM query.j_license  jl
               JOIN query.r_licenselicensetype rllt
                   ON jl.jobid = rllt.licensejobid
               JOIN query.j_licensetype jlt
                   ON jlt.jobid = rllt.licensetypejobid
         -- join query.r_licenseaddrpremises rlad on RLAD.LICENSEJOBID = JL.JOBID
         --join query.o_address addr on ADDR.OBJECTID = RLAD.PREMISESOBJECTID
         WHERE jlt.statusname IN ('ACTIVE',
                                  'R64B',
                                  'SUREND',
                                  'SLMSHD',
                                  'SUSPEN',
                                  'REVPEN');
BEGIN
    dbms_output.put_line('Starting... ');

    DELETE FROM abc.bcp_activelicenses;

    COMMIT;


    OPEN act_lic_cur;

    LOOP
        FETCH act_lic_cur BULK COLLECT INTO l_act_lic LIMIT c_limit;

        EXIT WHEN act_lic_cur%NOTFOUND;

        FORALL i IN INDICES OF l_act_lic SAVE EXCEPTIONS
            INSERT INTO abc.bcp_activelicenses
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
END bcp_statewideactivelicenses;
/
