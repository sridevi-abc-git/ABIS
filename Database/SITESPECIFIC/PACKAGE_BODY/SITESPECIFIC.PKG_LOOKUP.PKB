CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_lookup
AS
    -- **************************************************************************
    -- File:        PKG_LOOKUP.PKB
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
     * ListLicensees
     *-------------------------------------------------------------------------*/
    PROCEDURE listlicensees(a_object           udt_id,
                            a_relationshipdef  udt_id,
                            a_endpoint         udt_endpoint,
                            a_searchstring     VARCHAR2,
                            a_objects      OUT udt_objectlist)
    IS
        t_jobid   udt_id;
    BEGIN
        t_jobid     := api.pkg_columnquery.VALUE(a_object, 'JobId');

        a_objects   := api.udt_objectlist();

        IF a_searchstring IS NULL THEN
            /* Being used as a Drop Down */

            --get the LE for all jobs it is directly related to
            FOR c
                IN (SELECT r.toobjectid
                      FROM api.jobs  j
                           JOIN api.relationships r
                               ON r.fromobjectid = j.jobid
                     WHERE j.jobid = t_jobid
                       AND r.endpointid IN
                               (api.pkg_configquery.endpointidforname(
                                    'j_License',
                                    'LicenseeLegalEntity'),
                                api.pkg_configquery.endpointidforname(
                                    'j_License',
                                    'P12Licensee'),
                                api.pkg_configquery.endpointidforname(
                                    'j_Application',
                                    'Applicant'),
                                api.pkg_configquery.endpointidforname(
                                    'j_Application',
                                    'P12Applicant'),
                                api.pkg_configquery.endpointidforname(
                                    'j_Investigation',
                                    'Licensee')))
            LOOP
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(c.toobjectid);
            END LOOP;

            --get the LE for the License if this process is on the License Type
            FOR c
                IN (SELECT le.toobjectid
                      FROM api.jobs  j
                           JOIN api.relationships l
                               ON l.fromobjectid = j.jobid
                           JOIN api.relationships le
                               ON le.fromobjectid = l.toobjectid
                     WHERE j.jobid = t_jobid
                       AND l.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_LicenseType',
                               'License')
                       AND le.endpointid IN
                               (api.pkg_configquery.endpointidforname(
                                    'j_License',
                                    'LicenseeLegalEntity'),
                                api.pkg_configquery.endpointidforname(
                                    'j_License',
                                    'P12Licensee')))
            LOOP
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(c.toobjectid);
            END LOOP;
        END IF;
    END;


    --------------------------------------------------------------------------
    -- FindUsersForReminder
    --------------------------------------------------------------------------
    PROCEDURE findusersforreminder(a_object           udt_id,
                                   a_relationshipdef  udt_id,
                                   a_endpoint         udt_endpoint,
                                   a_searchstring     VARCHAR2,
                                   a_relatedobjectids OUT udt_objectlist)
    IS
        t_remindercreator   VARCHAR2(30);
        t_effectiveuser     udt_id := api.pkg_securityquery.effectiveuserid;
    BEGIN
        IF a_searchstring IS NULL THEN         /* Being used as a Drop Down */
            a_relatedobjectids   := api.udt_objectlist();

            FOR c_users IN (SELECT DISTINCT r2.fromobjectid userid
                              FROM api.users  u
                                   JOIN api.relationships r1
                                       ON r1.fromobjectid = u.userid
                                      AND r1.endpointid IN
                                              (api.pkg_configquery.endpointidforname(
                                                   'users',
                                                   'Office'),
                                               api.pkg_configquery.endpointidforname(
                                                   'users',
                                                   'SecondaryOffice'))
                                   JOIN api.relationships r2
                                       ON r2.toobjectid = r1.toobjectid
                                      AND r2.endpointid IN
                                              (api.pkg_configquery.endpointidforname(
                                                   'users',
                                                   'Office'),
                                               api.pkg_configquery.endpointidforname(
                                                   'users',
                                                   'SecondaryOffice'))
                             WHERE u.userid = t_effectiveuser
                               AND r2.fromobjectid <> u.userid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                    api.udt_object(c_users.userid);
            END LOOP;
        END IF;                                    --if a_SearchString is null
    END findusersforreminder;

    ------------------------------------------------------------------------
    --FindJobFees
    --Find Fees for the Modify Fee Procedure
    --this lookup procedure will only work for a drop down Dynamic Detail.
    ------------------------------------------------------------------------

    PROCEDURE findjobfees(a_object           udt_id,
                          a_relationshipdef  udt_id,
                          a_endpoint         udt_endpoint,
                          a_searchstring     VARCHAR2,
                          a_objects      OUT udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_removeobjects         api.udt_objectlist;
        t_earnedfees            api.udt_objectlist;
        t_jobid                 udt_id
            := api.pkg_columnquery.VALUE(a_object, 'JobId');
        t_index                 NUMBER;
        t_paytransobjectdefid   udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_PaymentTransactions');
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_removeobjects       := api.udt_objectlist();
        t_earnedfees          := api.udt_objectlist();
        extension.pkg_cxproceduralsearch.initializesearch('o_Fee');
        extension.pkg_cxproceduralsearch.searchbyindex('JobId',
                                                       t_jobid,
                                                       NULL);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        -- Get Fees that are already voided
        SELECT api.udt_object(r.feeobjectid)
          BULK COLLECT INTO t_removeobjects
          FROM query.p_modifyfee  m
               JOIN query.r_modifyfeefee r
                   ON r.modifyfeeprocessid = m.objectid
         WHERE m.jobid = t_jobid
           AND m.outcome IS NOT NULL
           AND m.modifytype = 'Void Fee';

          -- Get Fees that have payments that are already earned
          SELECT api.udt_object(qf.objectid)        --APatterson: PIP Task 8.5
            BULK COLLECT INTO t_earnedfees
            FROM api.fees f
                 JOIN api.registeredexternalobjects ef
                     ON ef.linkvalue = TO_CHAR(f.feeid)
                 JOIN query.o_fee qf ON qf.objectid = ef.objectid
                 JOIN api.feetransactions ft ON ft.feeid = f.feeid
                 JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                     ON reo.linkvalue = TO_CHAR(ft.transactionid)
                 JOIN query.o_paymenttransactions pt
                     ON pt.objectid = reo.objectid
           WHERE f.jobid = t_jobid
             AND pt.paymentstatus IS NOT NULL
        GROUP BY qf.objectid;

        -- Combine the two collections
        extension.pkg_collectionutils.append(t_removeobjects, t_earnedfees);

          -- Remove the voided and earned fees from the list
          SELECT api.udt_object(objectid)
            BULK COLLECT INTO a_objects
            FROM (SELECT objectid
                    FROM TABLE(CAST(t_unfilteredobjects AS api.udt_objectlist))
                  MINUS
                  SELECT objectid
                    FROM TABLE(CAST(t_removeobjects AS api.udt_objectlist)))
        ORDER BY api.pkg_columnquery.datevalue(objectid, 'TransactionDate');

        t_unfilteredobjects.delete;
    END findjobfees;

    ----------------------------------------------------------------------------------------------------
    --  FindLicenseTypeCategory() -- PUBLIC
    -- This will get all the LTCs related to a License as either Primaries or Secondaries.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE findlicensetypecategory(a_object           udt_id,
                                      a_relationshipdef  udt_id,
                                      a_endpoint         udt_endpoint,
                                      a_searchstring     VARCHAR2,
                                      a_objects      OUT udt_objectlist)
    AS
        t_jobid   udt_id;
    BEGIN
        a_objects   := api.udt_objectlist();
        t_jobid     := api.pkg_columnquery.numericvalue(a_object, 'JobId');

        SELECT api.udt_object(x.objectid)
          BULK COLLECT INTO a_objects
          FROM (SELECT ltp.licensetypecategoryobjectid objectid
                  FROM query.j_license  l
                       JOIN query.r_licenselicensetype r
                           ON r.licensejobid = l.jobid
                       JOIN query.j_licensetype lt
                           ON lt.jobid = r.licensetypejobid
                       JOIN query.r_licensetypeltcatprimary ltp
                           ON ltp.licensetypejobid = lt.jobid
                 WHERE l.jobid = t_jobid
                   AND lt.statusname = 'ACTIVE'
                UNION
                SELECT slt.licensetypecategoryobjectid
                  FROM query.j_license  l
                       JOIN query.r_licenselicensetype r
                           ON r.licensejobid = l.jobid
                       JOIN query.r_licensetypeltcatsecondary slt
                           ON slt.licensetypejobid = r.licensetypejobid
                 WHERE l.jobid = t_jobid
                   AND slt.status = 'ACTIVE') x;
    END findlicensetypecategory;
END pkg_lookup;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_LOOKUP TO POSSEEXTENSIONS;
