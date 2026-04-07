CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_abcsearch
IS
    -- **************************************************************************
    -- File:        PKG_ABCSEARCH.pkb
    -- Author:      CX
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                     Comment
    -- 08/16/2018 TJL           Initial Check-in
    -- 03/08/2018 TJL           WO 13579 Added missing procedure for P12A
    -- 10/17/2018 NW            W0 15584 Truncated SSN causes search problem
    -- 12/10/2018 NW            Delete changes made for WO13579 - Added missing procedure for P12A
    -- 03/15/2019 PK            WO 13953 Added Search Functionality For Impact Inspections
    -- 02/06/2019 PK            Formatted code for Find Inspection
    -- 02/11/2019 SS   WO 17279 fixing for type 49 to include MGR fee in t_objectlist
    -- 05/08/2019 PK            Added search by district to Impact Inspections
    -- 07/24/2019 TJL  WO 17980 Added new search procedure findpaymenttransunearned
    -- 10/10/2019 TJL  WO 17980 Corrected bug on handling payment transfers
    -- 12/03/2019 TJL  WO 19946 Corrected bug in showing Partially earned payment transaction
    -- 02/12/2020 TJL  WO 20483 Added filter for license type 75 to exclude certain license types
    --                           in procedures pltobjectsecondaryltsearch and licensetypejobsltsearch
    -- 03/19/2020 TJL  WO 20884 Added SRV filter to procedure findpaymenttransunearned
    -- 07/23/2020 TJL  WO 22226 Change findrefundpayment procedure to return zero amount refunds
    -- 10/06/2020 TJL  WO 22281 Changed findjobpayment to return reverse refunds when no money
    --                            was returned 100% server charge. Kept old version for reference
    --                            not used any more.
    --8/18/2021   PK   WO 25997 Add secondary type 58 to master type 75 undoing the changes done by Tim for WO 20483 for only type 58.
    -- 12/09/2021 SF(CX)        Added wrapper procedure for findpaymenttransactions so it can be used by the new StaffUI system.
    -- 04/01/2024 PK   WO35704  Added LSPID to search screen Caterer/Event Auth Search
    -- 09/26/2025  PK   6681    Changes social secutiry to varchar to fix SSN Person Search in le search
    -- 03/23/2026  PK   1037    ABIS Search - Adding Address Line 2 tp Procedure FindLicenseandApplication
    -- 03/24/2026  PK   1037    ABIS Search - Adding Address Line 2 tp Procedure FindPerson
    -- 03/26/2026  Sridevi   1037    ABIS Company Search - Adding Address Line 2 tp Procedure FindCompany

 
    -- **************************************************************************

    ---------------------------------------------------------
    --  FindUserOffices() -- PUBLIC
    --  Used by FindABC19Monthly and FindUserProcesses
    ---------------------------------------------------------
    PROCEDURE finduseroffices(a_userid udt_id, a_validofficeidlist IN OUT udt_idlist)
    IS
        t_temp1           udt_idlist;
        t_hqcount         NUMBER;
        t_southerncount   NUMBER;
        t_northerncount   NUMBER;
    BEGIN
        -- Add All Office objectids to Valid Office Id List when user is related to a Headquarters office
        SELECT  --+ CARDINALITY(o 2)
               COUNT(r.toobjectid)
          INTO t_hqcount
          FROM api.relationships r
               JOIN TABLE(
                        CAST(
                            api.pkg_simplesearch.castableobjectsbyindex('o_Office', 'OfficeType', 'HEADQUARTERS') AS api.udt_objectlist))
                    o
               ON o.objectid = r.toobjectid
         WHERE r.fromobjectid = a_userid
           AND (r.endpointid = api.pkg_configquery.endpointidforname('Users', 'SecondaryOffice')
             OR r.endpointid = api.pkg_configquery.endpointidforname('Users', 'Office'));

        IF t_hqcount > 0 THEN
            SELECT o.objectid
              BULK COLLECT INTO t_temp1
              FROM query.o_office o;

            extension.pkg_collectionutils.append(a_validofficeidlist, t_temp1);
        ELSE
            -- Add all Office objectids to Valid Office Id List when user is related directly to those Offices
            SELECT r.toobjectid
              BULK COLLECT INTO a_validofficeidlist
              FROM api.relationships r
             WHERE r.fromobjectid = a_userid
               AND (r.endpointid = api.pkg_configquery.endpointidforname('Users', 'SecondaryOffice')
                 OR r.endpointid = api.pkg_configquery.endpointidforname('Users', 'Office'));

            -- Add Southern division district office objectids to Valid Office Id List when user is related to Southern Division Office
            SELECT  --+ CARDINALITY(o 1)
                   COUNT(r.relationshipid)
              INTO t_southerncount
              FROM api.relationships r
                   JOIN TABLE(
                            CAST(
                                api.pkg_simplesearch.castableobjectsbyindex('o_Office',
                                                                            'OfficeName',
                                                                            'SOUTHERN DIVISION') AS api.udt_objectlist))
                        o
                   ON o.objectid = r.toobjectid
             WHERE r.fromobjectid = a_userid
               AND (r.endpointid = api.pkg_configquery.endpointidforname('Users', 'SecondaryOffice')
                 OR r.endpointid = api.pkg_configquery.endpointidforname('Users', 'Office'));

            IF t_southerncount > 0 THEN
                SELECT  --+ CARDINALITY(x 20)
                       x.objectid
                  BULK COLLECT INTO t_temp1
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex('o_Office', 'Division', 'Southern') AS api.udt_objectlist))
                       x;
            END IF;

            extension.pkg_collectionutils.append(a_validofficeidlist, t_temp1);

            -- Add Northern division district office objectids to Valid Office Id List when user is related to Northern Division Office
            SELECT  --+ CARDINALITY(o 1)
                   COUNT(r.relationshipid)
              INTO t_northerncount
              FROM api.relationships r
                   JOIN TABLE(
                            CAST(
                                api.pkg_simplesearch.castableobjectsbyindex('o_Office',
                                                                            'OfficeName',
                                                                            'NORTHERN DIVISION') AS api.udt_objectlist))
                        o
                   ON o.objectid = r.toobjectid
             WHERE r.fromobjectid = a_userid
               AND (r.endpointid = api.pkg_configquery.endpointidforname('Users', 'SecondaryOffice')
                 OR r.endpointid = api.pkg_configquery.endpointidforname('Users', 'Office'));

            IF t_northerncount > 0 THEN
                SELECT  --+ CARDINALITY(x 20)
                       x.objectid
                  BULK COLLECT INTO t_temp1
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex('o_Office', 'Division', 'Northern') AS api.udt_objectlist))
                       x;
            END IF;

            extension.pkg_collectionutils.append(a_validofficeidlist, t_temp1);
        END IF;
    END finduseroffices;

    /**************************************************************************************************
        * FindABC19Monthly() -- PUBLIC
        *   Search for for ABC-19 Monthly Objects
        **************************************************************************************************/
    PROCEDURE findabc19monthly(a_dup_monthnumber  NUMBER,
                               a_year             NUMBER,
                               a_dup_districtoffice NUMBER,  --ObjectId of Office
                               a_objects      OUT api.udt_objectlist)
    IS
        t_validofficeidlist        udt_idlist;
        t_unfilteredobjects        api.udt_objectlist;
        t_districtofficeobjectid   udt_id;
    BEGIN
        -- Perform search without any filtering
        t_unfilteredobjects   := api.udt_objectlist();
        a_objects             := api.udt_objectlist();
        extension.pkg_cxproceduralsearch.initializesearch('o_ABC19Monthly');

        extension.pkg_cxproceduralsearch.searchbyindex('dup_Month',
                                                       a_dup_monthnumber,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('Year',
                                                       a_year,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Office',
                                                              'ObjectId',
                                                              a_dup_districtoffice,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        finduseroffices((api.pkg_securityquery.effectiveuserid), t_validofficeidlist);

        a_objects             := api.udt_objectlist();

        FOR c5 IN (SELECT  --+ CARDINALITY(t 1)
                          t.objectid objectid
                     FROM TABLE(CAST(t_unfilteredobjects AS api.udt_objectlist)) t)
        LOOP
            t_districtofficeobjectid   := api.pkg_columnquery.VALUE(c5.objectid, 'DistrictOfficeObjectId');

            FOR i IN 1 .. t_validofficeidlist.COUNT
            LOOP
                IF t_districtofficeobjectid = t_validofficeidlist(i) THEN
                    a_objects.EXTEND(1);
                    a_objects(a_objects.COUNT)   := api.udt_object(c5.objectid);
                    EXIT;
                END IF;
            END LOOP;
        END LOOP;

        IF a_objects.COUNT = 0
       AND t_unfilteredobjects.COUNT > 0 THEN
            api.pkg_errors.raiseerror(-20000, 'You do not have security to view the results for this office.');
        ELSE
            NULL;
        END IF;
    END findabc19monthly;

    PROCEDURE findaccessgroups(a_description                VARCHAR2,
                               a_excludeobjectids           VARCHAR2,
                               a_objectlist      OUT NOCOPY api.udt_objectlist)
    IS
        t_excludeobjectlist   api.udt_objectlist;
        t_start               NUMBER := 1;
        t_excludeobjectids    VARCHAR2(1000)
                                  :=    a_excludeobjectids
                                     || ',';
        t_objectlist          api.udt_objectlist;
    BEGIN
        a_objectlist          := api.udt_objectlist();
        t_objectlist          := api.udt_objectlist();
        t_excludeobjectlist   := api.udt_objectlist();

        WHILE INSTR(t_excludeobjectids, ',', t_start) > 0
          AND a_excludeobjectids IS NOT NULL
        LOOP
            t_excludeobjectlist.EXTEND(1);
            t_excludeobjectlist(t_excludeobjectlist.COUNT)   :=
                api.udt_object(
                    SUBSTR(t_excludeobjectids, t_start, INSTR(t_excludeobjectids, ',', t_start) - t_start));
            t_start   := INSTR(t_excludeobjectids, ',', t_start) + 2;
        END LOOP;

        -- Search and Register external object
        t_objectlist          :=
            api.pkg_simplesearch.castableobjectsbyindex('o_AccessGroups',
                                                        'Description',
                                                           a_description
                                                        || '%');

        FOR c IN (SELECT  --+ CARDINALITY(o 1)
                         o.objectid
                    FROM TABLE(CAST(t_objectlist AS api.udt_objectlist)) o
                   WHERE o.objectid NOT IN (SELECT  --+ CARDINALITY(e 1)
                                                   e.objectid
                                              FROM TABLE(CAST(t_excludeobjectlist AS api.udt_objectlist)) e))
        LOOP
            a_objectlist.EXTEND(1);
            a_objectlist(a_objectlist.COUNT)   := api.udt_object(c.objectid);
        END LOOP;

        -- Remove Users from Access Groups that have been deleted
        FOR c IN (SELECT agu.relationshipid
                    FROM query.o_accessgroups ag
                         JOIN query.r_accessgroupusers agu
                         ON agu.accessgroupobjectid = ag.objectid
                   WHERE ag.accessgroupid IS NULL)
        LOOP
            api.pkg_relationshipupdate.remove(c.relationshipid);
        END LOOP;
    END;

    PROCEDURE findaccusation(a_status                     VARCHAR2,
                             a_createddate                DATE,
                             a_createddateupper           DATE,
                             a_externalfilenum            VARCHAR2,
                             a_licensenumber              VARCHAR2,
                             a_currentobjectids           VARCHAR2,
                             a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_objectids           udt_idlist;
        t_status              VARCHAR2(6);
        t_findaccusation      NUMBER(9, 0);
        t_count               NUMBER(9, 0);
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_findaccusation      := api.pkg_constantquery.VALUE('FINDACCUSATION');

        extension.pkg_cxproceduralsearch.initializesearch('j_Accusation');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     t_status,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                       a_externalfilenum,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                       a_licensenumber,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        SELECT objectid
          BULK COLLECT INTO t_objectids
          FROM TABLE(CAST(t_unfilteredobjects AS api.udt_objectlist))
         WHERE objectid NOT IN
                   (    SELECT NVL(REGEXP_SUBSTR(a_currentobjectids,
                                                 '[^, ]+',
                                                 1,
                                                 ROWNUM),
                                   0)
                          FROM DUAL
                    CONNECT BY ROWNUM - 1 <= LENGTH(a_currentobjectids) - LENGTH(REPLACE(a_currentobjectids, ',')));

        t_count               := t_objectids.COUNT;

        IF t_count <= t_findaccusation THEN
            a_objects   := extension.pkg_utils.converttoobjectlist(t_objectids);
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findaccusation
                                      || ' results were found. Please refine your search criteria.');
        END IF;


        t_unfilteredobjects.delete;
    END findaccusation;

    PROCEDURE findactivesuspendedlicense(a_externalfilenum            VARCHAR2,
                                         a_licenseenames              VARCHAR2,
                                         a_dup_premaddressline1       VARCHAR2,
                                         a_dup_premaddressuscity      VARCHAR2,
                                         a_dup_premzipcode            VARCHAR2,
                                         a_dup_dbas                   VARCHAR2,
                                         a_createddate                DATE,
                                         a_createddateupper           DATE,
                                         a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_activeorsuspended   VARCHAR2(1);
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_externalfilenum IS NOT NULL
        OR a_licenseenames IS NOT NULL
        OR a_dup_premaddressline1 IS NOT NULL
        OR a_dup_premaddressuscity IS NOT NULL
        OR a_dup_premzipcode IS NOT NULL
        OR a_dup_dbas IS NOT NULL
        OR a_createddate IS NOT NULL
        OR a_createddateupper IS NOT NULL THEN
            t_activeorsuspended   := 'Y';
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('j_License');

        IF a_createddate IS NOT NULL
        OR a_createddateupper IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         a_createddate,
                                                         a_createddateupper,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL);
        END IF;

        IF a_externalfilenum IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                           a_externalfilenum,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_dup_premaddressline1 IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'AddressLine1',
                                                                  a_dup_premaddressline1,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_premaddressuscity IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'USACity',
                                                                  a_dup_premaddressuscity,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_premzipcode IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'ZipCode',
                                                                  a_dup_premzipcode,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_dbas IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                                  'DBA',
                                                                  a_dup_dbas,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        --extension.pkg_cxproceduralsearch.SearchByIndex('dup_IsActiveOrSuspended',t_ActiveOrSuspended,null,false);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF a_licenseenames IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.initializesearch('j_License');
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonLicensee',
                                                                  'dup_FormattedPersonNameSearch',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyLicensee',
                                                                  'CompanyName',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12PersonLicensee',
                                                                  'dup_FormattedPersonNameSearch',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12CompanyLicensee',
                                                                  'CompanyName',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);

            IF t_unfilteredobjects.FIRST IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'and');
            ELSIF t_unfilteredobjects.FIRST IS NULL THEN
                extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'or', 'or');
            END IF;
        END IF;

        a_objects             := t_unfilteredobjects;
        t_unfilteredobjects.delete;
    END findactivesuspendedlicense;

    PROCEDURE findaddress(a_addressline1               VARCHAR2,
                          a_addressline2               VARCHAR2,
                          a_usacity                    VARCHAR2,
                          a_usastate                   VARCHAR2,
                          a_zipcode                    VARCHAR2,
                          a_country                    VARCHAR2,
                          a_censustract                NUMBER,
                          a_addresskeywords            VARCHAR2,
                          a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                          a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_findaddress           NUMBER(9, 0);
        t_count                 NUMBER(9, 0);
        t_overridesearchlimit   VARCHAR2(1);
    BEGIN
        t_overridesearchlimit   := NVL(a_overridesearchlimit, 'N');
        a_objects               := api.udt_objectlist();
        t_unfilteredobjects     := api.udt_objectlist();
        t_findaddress           := api.pkg_constantquery.VALUE('FINDADDRESS');

        -- If all arguments are null, raise an intelligent error and don't run the search.
        IF a_addressline1 IS NULL
       AND a_addressline2 IS NULL
       AND a_usacity IS NULL
       AND a_usastate IS NULL
       AND a_zipcode IS NULL
       AND a_country IS NULL
       AND a_censustract IS NULL
       AND a_addresskeywords IS NULL THEN
            api.pkg_errors.raiseerror(-20000, 'Please enter some search criteria and then click Search.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_Address');

        IF a_addressline1 IS NOT NULL
       AND a_zipcode IS NULL
       AND a_usacity IS NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine1',
                                                           a_addressline1,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine2',
                                                           a_addressline2,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('USAState',
                                                           a_usastate,
                                                           a_usastate,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.filterobjects('Country',
                                                           a_country,
                                                           a_country,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('CensusTract',
                                                           a_censustract,
                                                           a_censustract,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbykeywords(a_addresskeywords);
        ELSIF a_addressline1 IS NOT NULL
          AND a_zipcode IS NOT NULL
          AND a_usacity IS NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine1',
                                                           a_addressline1,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine2',
                                                           a_addressline2,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('ZipCode',
                                                           a_zipcode,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('USAState',
                                                           a_usastate,
                                                           a_usastate,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.filterobjects('Country',
                                                           a_country,
                                                           a_country,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('CensusTract',
                                                           a_censustract,
                                                           a_censustract,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbykeywords(a_addresskeywords);
        ELSIF a_addressline1 IS NOT NULL
          AND a_zipcode IS NULL
          AND a_usacity IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine1',
                                                           a_addressline1,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine2',
                                                           a_addressline2,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('ZipCode',
                                                           a_zipcode,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('USACity',
                                                           a_usacity,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('USAState',
                                                           a_usastate,
                                                           a_usastate,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.filterobjects('Country',
                                                           a_country,
                                                           a_country,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('CensusTract',
                                                           a_censustract,
                                                           a_censustract,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbykeywords(a_addresskeywords);
        ELSIF a_addressline1 IS NULL
          AND a_zipcode IS NOT NULL
          AND a_usacity IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine2',
                                                           a_addressline2,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('ZipCode',
                                                           a_zipcode,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('USACity',
                                                           a_usacity,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('USAState',
                                                           a_usastate,
                                                           a_usastate,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.filterobjects('Country',
                                                           a_country,
                                                           a_country,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('CensusTract',
                                                           a_censustract,
                                                           a_censustract,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbykeywords(a_addresskeywords);
        ELSIF a_addressline1 IS NULL
          AND a_zipcode IS NOT NULL
          AND a_usacity IS NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine2',
                                                           a_addressline2,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('ZipCode',
                                                           a_zipcode,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('USAState',
                                                           a_usastate,
                                                           a_usastate,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.filterobjects('Country',
                                                           a_country,
                                                           a_country,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('CensusTract',
                                                           a_censustract,
                                                           a_censustract,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbykeywords(a_addresskeywords);
        ELSE
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine1',
                                                           a_addressline1,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('AddressLine2',
                                                           a_addressline2,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('USACity',
                                                           a_usacity,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('USAState',
                                                           a_usastate,
                                                           NULL,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.searchbyindex('ZipCode',
                                                           a_zipcode,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('Country',
                                                           a_country,
                                                           NULL,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.searchbyindex('CensusTract',
                                                           a_censustract,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbykeywords(a_addresskeywords);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF t_overridesearchlimit = 'Y' THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            t_count   := t_unfilteredobjects.COUNT;

            IF t_count <= t_findaddress THEN
                a_objects   := t_unfilteredobjects;
            ELSE
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_findaddress
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        END IF;

        t_unfilteredobjects.delete;
    END findaddress;

    PROCEDURE findapplication(a_externalfilenum            VARCHAR2,
                              a_primarylicensee            VARCHAR2,
                              a_premaddressline1           VARCHAR2,
                              a_premuscity                 VARCHAR2,
                              a_premzipcode                VARCHAR2,
                              a_dup_dbas                   VARCHAR2,
                              a_createddate                DATE,
                              a_createddateupper           DATE,
                              a_status                     VARCHAR2,
                              a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_status              VARCHAR2(60);
    BEGIN
        -- User needs to select Status Description, but SearchByJob procedure only takes StatusName.
        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                       JOIN api.jobstatuses js
                       ON js.statusid = s.statusid
                      AND js.jobtypeid = api.pkg_configquery.objectdefidforname('j_Application')
                 WHERE s.description = a_status
                   AND js.statustype NOT IN ('C', 'X');
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 ''''
                                              || a_status
                                              || ''' is not a valid status for this search.');
            END;
        END IF;

        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('j_Application');
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,  --a_ExternalFileNum,
                                                     t_status,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                       a_externalfilenum,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_PrimaryLicensee',
                                                       a_primarylicensee,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_PremAddressLine1',
                                                       a_premaddressline1,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_PremUSCity',
                                                       a_premuscity,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_PremZipCode',
                                                       a_premzipcode,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_DBAs',
                                                       a_dup_dbas,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF t_status IS NULL THEN
            --Filter the Objects by removing all Applications in the Completed or Canceled statuses.
            SELECT api.udt_object(a.jobid)
              BULK COLLECT INTO a_objects
              FROM api.jobs a
                   JOIN api.jobstatuses js
                   ON js.jobtypeid = a.jobtypeid
                  AND js.statusid = a.statusid
             WHERE a.jobid IN (SELECT * FROM TABLE(t_unfilteredobjects))
               AND js.statustype NOT IN ('C', 'X');
        ELSE
            a_objects   := t_unfilteredobjects;
        END IF;
    END findapplication;

    PROCEDURE findattorney(a_lastname                   VARCHAR2,
                           a_firstname                  VARCHAR2,
                           a_firmname                   VARCHAR2,
                           a_addressline1               VARCHAR2,
                           a_city                       VARCHAR2,
                           a_state                      VARCHAR2,
                           a_zipcode                    VARCHAR2,
                           a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                           a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_findattorney          NUMBER(9, 0);
        t_count                 NUMBER(9, 0);
        t_overridesearchlimit   VARCHAR2(1);
    BEGIN
        t_overridesearchlimit   := NVL(a_overridesearchlimit, 'N');
        a_objects               := api.udt_objectlist();
        t_unfilteredobjects     := api.udt_objectlist();
        t_findattorney          := api.pkg_constantquery.VALUE('FINDATTORNEY');

        extension.pkg_cxproceduralsearch.initializesearch('o_Attorney');
        extension.pkg_cxproceduralsearch.searchbyindex('LastName',
                                                       a_lastname,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('FirstName',
                                                       a_firstname,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('FirmName',
                                                       a_firmname,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                              'AddressLine1',
                                                              a_addressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                              'USACity',
                                                              a_city,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                              'USAState',
                                                              a_state,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                              'ZipCode',
                                                              a_zipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');


        IF t_overridesearchlimit = 'Y' THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            t_count   := t_unfilteredobjects.COUNT;

            IF t_count <= t_findattorney THEN
                a_objects   := t_unfilteredobjects;
            ELSE
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_findattorney
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        END IF;

        t_unfilteredobjects.delete;
    END findattorney;

    ---------------------------------------------------------------------------------------------------
    PROCEDURE findbeerkegtags(a_tagnumber VARCHAR2, a_objects OUT NOCOPY api.udt_objectlist)
    AS
    BEGIN
        a_objects   := api.udt_objectlist();

        IF SUBSTR(a_tagnumber, 1, 1) BETWEEN 'A' AND 'Z' THEN
            -- If they entered the Tag Number with the leading character, then search based on the whole tag
            SELECT api.udt_object(t.objectid)
              BULK COLLECT INTO a_objects
              FROM beerkegtags_t t
             WHERE t.tagnumber = a_tagnumber;
        ELSE
            -- If they entered the Tag Number without the leading character, then search for tags irrespective of the alpha character
            SELECT api.udt_object(t.objectid)
              BULK COLLECT INTO a_objects
              FROM beerkegtags_t t
             WHERE SUBSTR(t.tagnumber, 2) = a_tagnumber;
        END IF;
    END findbeerkegtags;

    ---------------------------------------------------------------------------------------------------
    --  FindBranchLicenseType() -- PUBLIC
    ---------------------------------------------------------------------------------------------------
    PROCEDURE findbranchlicensetype(a_licenseexternalfilenum     VARCHAR2,
                                    a_licenseenames              VARCHAR2,
                                    a_licenseaddressline1        VARCHAR2,
                                    a_licenseuscity              VARCHAR2,
                                    a_licensezipcode             VARCHAR2,
                                    a_licensedbas                VARCHAR2,
                                    a_fromprimarylicensetype     NUMBER,
                                    a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        SUBTYPE udt_licensetypecodes IS pkg_licensetype.udt_licensetypecodes;

        t_licensetypecodes       udt_licensetypecodes;
        t_unfilteredobjects      api.udt_objectlist;
        t_validmasterltobjects   api.udt_objectlist;
    BEGIN
        a_objects                := api.udt_objectlist();
        t_unfilteredobjects      := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonLicensee',
                                                              'dup_FormattedPersonNameSearch',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseType',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchPy',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12PersonLicensee',
                                                              'dup_FormattedPersonNameSearch',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseType',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchPy',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyLicensee',
                                                              'CompanyName',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseType',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchPy',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12CompanyLicensee',
                                                              'CompanyName',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseType',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchPy',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        t_licensetypecodes       := pkg_licensetype.validmasterlicensetypesonplt(a_fromprimarylicensetype);

        t_validmasterltobjects   := api.udt_objectlist();

        FOR i IN 1 .. t_licensetypecodes.COUNT
        LOOP
            extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
            extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseTypeCode',
                                                           t_licensetypecodes(i),
                                                           t_licensetypecodes(i),
                                                           FALSE);
            extension.pkg_cxproceduralsearch.performsearch(t_validmasterltobjects, 'and', 'or');
        END LOOP;

        IF t_validmasterltobjects.COUNT > 0 THEN
            SELECT api.udt_object(uo.objectid)
              BULK COLLECT INTO a_objects
              FROM TABLE(CAST(t_unfilteredobjects AS api.udt_objectlist)) uo
                   JOIN TABLE(CAST(t_validmasterltobjects AS api.udt_objectlist)) mlt
                   ON mlt.objectid = uo.objectid
             WHERE uo.objectid <> a_fromprimarylicensetype
               AND api.pkg_columnquery.VALUE(uo.objectid, 'BLTJobIds') IS NULL
               AND api.pkg_columnquery.VALUE(uo.objectid, 'BPLTObjectIds') IS NULL;
        ELSE
            a_objects   := t_unfilteredobjects;
        END IF;

        t_unfilteredobjects.delete;
        t_validmasterltobjects.delete;
    END findbranchlicensetype;

    PROCEDURE findbranchprimarylicensetype(a_licenseexternalfilenum     VARCHAR2,
                                           a_licenseenames              VARCHAR2,
                                           a_licenseaddressline1        VARCHAR2,
                                           a_licenseuscity              VARCHAR2,
                                           a_licensezipcode             VARCHAR2,
                                           a_licensedbas                VARCHAR2,
                                           a_fromprimarylicensetype     NUMBER,
                                           a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        SUBTYPE udt_licensetypecodes IS pkg_licensetype.udt_licensetypecodes;

        t_licensetypecodes       udt_licensetypecodes;
        t_unfilteredobjects      api.udt_objectlist;
        t_validmasterltobjects   api.udt_objectlist;
    BEGIN
        a_objects                := api.udt_objectlist();
        t_unfilteredobjects      := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonLicensee',
                                                              'dup_FormattedPersonNameSearch',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseTypeExp',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchS',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsNotIssuedVoided',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12PersonLicensee',
                                                              'dup_FormattedPersonNameSearch',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseTypeExp',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchS',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsNotIssuedVoided',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyApplicant',
                                                              'CompanyName',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseTypeExp',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchS',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsNotIssuedVoided',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12CompanyApplicant',
                                                              'CompanyName',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseTypeExp',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchS',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsNotIssuedVoided',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        t_licensetypecodes       := pkg_licensetype.validmasterlicensetypesonplt(a_fromprimarylicensetype);

        t_validmasterltobjects   := api.udt_objectlist();

        FOR i IN 1 .. t_licensetypecodes.COUNT
        LOOP
            extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('LicTypeCatPrimary',
                                                                  'LicenseTypeCode',
                                                                  t_licensetypecodes(i),
                                                                  t_licensetypecodes(i),
                                                                  FALSE);
            extension.pkg_cxproceduralsearch.performsearch(t_validmasterltobjects, 'and', 'or');
        END LOOP;

        IF t_validmasterltobjects.COUNT > 0 THEN
            SELECT api.udt_object(uo.objectid)
              BULK COLLECT INTO a_objects
              FROM TABLE(CAST(t_unfilteredobjects AS api.udt_objectlist)) uo
                   JOIN TABLE(CAST(t_validmasterltobjects AS api.udt_objectlist)) mlt
                   ON mlt.objectid = uo.objectid
             WHERE uo.objectid <> a_fromprimarylicensetype
               AND api.pkg_columnquery.VALUE(uo.objectid, 'BranchPLTIds') IS NULL
               AND api.pkg_columnquery.VALUE(uo.objectid, 'BranchLTIds') IS NULL;
        ELSE
            a_objects   := t_unfilteredobjects;
        END IF;

        t_unfilteredobjects.delete;
        t_validmasterltobjects.delete;
    END findbranchprimarylicensetype;

    /**************************************************************************************************
        * FindCompany() -- PUBLIC
        *   Search for Company Objects
        **************************************************************************************************/
    PROCEDURE findcompany(a_companyname                VARCHAR2,
                          a_addressline1               VARCHAR2,
                          a_addressline2               VARCHAR2,      ----added by sri
                          a_uscity                     VARCHAR2,
                          a_usstate                    VARCHAR2,
                          a_zipcode                    VARCHAR2,
                          a_keywords                   VARCHAR2,
                          a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                          a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_findcompany           NUMBER(9, 0);
        t_count                 NUMBER(9, 0);
        t_overridesearchlimit   VARCHAR2(1);
    BEGIN
        t_overridesearchlimit   := NVL(a_overridesearchlimit, 'N');
        a_objects               := api.udt_objectlist();
        t_unfilteredobjects     := api.udt_objectlist();
        t_findcompany           := api.pkg_constantquery.VALUE('FINDCOMPANY');

        extension.pkg_cxproceduralsearch.initializesearch('o_Company');

        IF a_companyname IS NOT NULL
        OR a_addressline1 IS NOT NULL
  --    OR a_addressline2 IS NOT NULL                            ----added by sri
        OR a_keywords IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbykeywords(   a_companyname
                                                              || '%');
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                                  'AddressLine1',
                                                                  a_addressline1,
                                                                  NULL,
                                                                  TRUE);
                                                                  
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',     ----added by sri
                                                                  'AddressLine2',
                                                                  a_addressline2,
                                                                  NULL,
                                                                  TRUE);                                                   
            extension.pkg_cxproceduralsearch.filterobjects('USCity',
                                                           a_uscity,
                                                           a_uscity,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.filterobjects('USState',
                                                           a_usstate,
                                                           a_usstate,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.filterobjects('ZipCode',
                                                           a_zipcode,
                                                           a_zipcode,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbykeywords(a_keywords);
        ELSE
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                                  'USACity',
                                                                  a_uscity,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                                  'USAState',
                                                                  a_usstate,
                                                                  NULL,
                                                                  FALSE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                                  'ZipCode',
                                                                  a_zipcode,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF t_overridesearchlimit = 'Y' THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            t_count   := t_unfilteredobjects.COUNT;

            IF t_count <= t_findcompany THEN
                a_objects   := t_unfilteredobjects;
            ELSE
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_findcompany
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        END IF;

        t_unfilteredobjects.delete;
    END findcompany;

    /*---------------------------------------------------------------------------
       * FindDishonorPayments()
       * This procedures is used to find the Dishonor Payment(s) Jobs within the search procedure.
       *-------------------------------------------------------------------------*/

    PROCEDURE finddishonorpayments(a_externalfilenum            VARCHAR2,
                                   a_batchdate                  DATE,
                                   a_batchdateupper             DATE,
                                   a_createddate                DATE,
                                   a_createddateupper           DATE,
                                   a_completeddate              DATE,
                                   a_completeddateupper         DATE,
                                   a_status                     VARCHAR2,
                                   a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects      api.udt_objectlist;
        t_objectids              udt_idlist;
        t_status                 VARCHAR2(6);
        t_finddishonorpayments   NUMBER(9, 0);
        t_count                  NUMBER(9, 0);
    BEGIN
        a_objects                := api.udt_objectlist();
        t_unfilteredobjects      := api.udt_objectlist();
        t_finddishonorpayments   := api.pkg_constantquery.VALUE('FINDDISHONORPAYMENTS');

        extension.pkg_cxproceduralsearch.initializesearch('j_DishonorPayments');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     a_externalfilenum,
                                                     t_status,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     a_completeddate,
                                                     a_completeddateupper);
        extension.pkg_cxproceduralsearch.searchbyindex('BatchDate', a_batchdate, a_batchdateupper);
        extension.pkg_cxproceduralsearch.performsearch(a_objects, 'and', 'none');

        t_count                  := a_objects.COUNT;

        IF t_count > t_finddishonorpayments THEN
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_finddishonorpayments
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
    END finddishonorpayments;

    PROCEDURE findescrow(a_escrowcompanyname          VARCHAR2,
                         a_addressline1               VARCHAR2,
                         a_uscity                     VARCHAR2,
                         a_usstate                    VARCHAR2,
                         a_zipcode                    VARCHAR2,
                         a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        extension.pkg_cxproceduralsearch.initializesearch('o_Escrow');
        extension.pkg_cxproceduralsearch.searchbyindex('EscrowCompanyName',
                                                       a_escrowcompanyname,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                              'AddressLine1',
                                                              a_addressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                              'USACity',
                                                              a_uscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                              'USAState',
                                                              a_usstate,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Address',
                                                              'ZipCode',
                                                              a_zipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');
        a_objects             := t_unfilteredobjects;
        t_unfilteredobjects.delete;
    END findescrow;

    PROCEDURE findfees(a_jobnumber VARCHAR2, a_objects OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        /*    extension.pkg_cxproceduralsearch.InitializeSearch('o_Fee');
                  extension.pkg_cxproceduralsearch.SearchByRelatedIndex('Investigation', 'dup_InvestigationNumber', a_JobNumber, null, false);
                  extension.pkg_cxproceduralsearch.PerformSearch(t_UnfilteredObjects, 'and', 'none');
                  --  No longer needed since there is no Investigation Number field plus the following search on the investigation job
                  -- would remove all values from a_Objects because of the a_AppendResultsType => 'none' rendering this useless.
              */

        extension.pkg_cxproceduralsearch.initializesearch('o_Fee');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Investigation',
                                                              'dup_LicenseNumber',
                                                              a_jobnumber,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('o_Fee');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_jobnumber,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_Fee');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Accusation',
                                                              'dup_LicenseNumber',
                                                              a_jobnumber,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_Fee');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_jobnumber,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_Fee');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('MiscellaneousFee',
                                                              'ExternalFileNum',
                                                              a_jobnumber,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_Fee');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('OneDayLicense',
                                                              'ExternalFileNum',
                                                              a_jobnumber,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_Fee');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('LicenseType',
                                                              'dup_LicenseExternalFileNum',
                                                              a_jobnumber,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');
        a_objects             := t_unfilteredobjects;
        t_unfilteredobjects.delete;
    END findfees;

    -------------------------------------
    PROCEDURE findfilteredcatererevent(a_objectid                   NUMBER,
                                       a_startdate                  DATE,
                                       a_enddate                    DATE,
                                       a_objects         OUT NOCOPY api.udt_objectlist)
    AS
        t_enddate   DATE;
        t_limit     NUMBER;
    BEGIN
        a_objects   := api.udt_objectlist();
        t_enddate   := TRUNC(a_enddate + 1);
        t_limit     := api.pkg_constantquery.VALUE('ADDRESSRELATIONSHIPS');

        SELECT api.udt_object(p.objectid)
          BULK COLLECT INTO a_objects
          FROM query.r_issuecaterereventauthaddress r
               JOIN query.p_issuecaterereventauth p
               ON p.processid = r.issuecaterereventauthprocessid
         WHERE r.eventaddressobjectid = a_objectid
           AND ((a_startdate IS NOT NULL
             AND t_enddate IS NOT NULL
             AND (a_startdate BETWEEN p.dateofeventfrom AND p.dateofeventto
               OR t_enddate BETWEEN p.dateofeventfrom AND p.dateofeventto
               OR p.dateofeventfrom BETWEEN a_startdate AND t_enddate))
             OR (a_startdate IS NULL
             AND t_enddate IS NOT NULL
             AND (p.dateofeventfrom <= t_enddate
               OR p.dateofeventto <= t_enddate))
             OR (a_startdate IS NOT NULL
             AND t_enddate IS NULL
             AND (p.dateofeventfrom >= a_startdate
               OR p.dateofeventto >= a_startdate)));

        IF a_objects.COUNT > t_limit THEN
            api.pkg_errors.raiseerror(-20000,
                                         'More than '
                                      || t_limit
                                      || ' results were found. Please refine your search criteria.');
        END IF;
    END findfilteredcatererevent;

    ---------------------------------------------
    PROCEDURE findfilteredfees(a_jobid                      udt_id,
                               a_startdate                  DATE,
                               a_enddate                    DATE,
                               a_cataepa                    VARCHAR2,
                               a_objects         OUT NOCOPY api.udt_objectlist)
    AS
        t_fees          api.udt_objectlist;
        t_enddate       DATE;
        t_startdate     DATE;
        t_feeobjdefid   udt_id;
    BEGIN
        t_feeobjdefid   := api.pkg_configquery.objectdefidforname('o_Fee');
        a_objects       := api.udt_objectlist();
        t_fees          := api.udt_objectlist();

        -- Get the feeids
        feesforfiltering(a_jobid,
                         a_startdate,
                         a_enddate,
                         a_cataepa,
                         t_fees);

        /* DREID - Old Code
                  select api.udt_Object(x.ObjectId)
                    bulk collect into a_Objects
                    from table(t_Fees) f
                    join table(cast(api.pkg_SimpleSearch.CastableObjectsByIndex('o_Fee','FeeId',f.ObjectId)as api.udt_ObjectList)) x on 1=1;
              */
        SELECT api.udt_object(reo.objectid)
          BULK COLLECT INTO a_objects
          FROM TABLE(t_fees) f
               JOIN api.registeredexternalobjects reo
               ON reo.linkvalue = TO_CHAR(f.objectid)
              AND reo.objectdefid = t_feeobjdefid;
    END findfilteredfees;

    PROCEDURE feesforfiltering(a_jobid                      udt_id,
                               a_startdate                  DATE,
                               a_enddate                    DATE,
                               a_cataepa                    VARCHAR2,
                               a_objects         OUT NOCOPY api.udt_objectlist)
    AS
        t_cataepa       VARCHAR2(1);
        t_enddate       DATE;
        t_findfees      NUMBER;
        t_feeobjdefid   udt_id;
    BEGIN
        t_feeobjdefid   := api.pkg_configquery.objectdefidforname('o_Fee');
        a_objects       := api.udt_objectlist();
        t_cataepa       := NVL(a_cataepa, 'N');
        t_enddate       := TRUNC(a_enddate + 1);

        IF t_cataepa = 'N' THEN
            /* commented out based on CX (Keaton Leikam) recomendation. Oct 10, 2012 */
            /*select api.udt_Object(f.FeeId)
                        bulk collect into a_Objects
                        from api.Fees f
                        join sitespecific.FeeSchedule_t t on t.ObjectId = sitespecific.pkg_Fees.GetLicFeeSchedulObjId(f.FeeId)
                       where f.JobId = a_JobId
                         and t.FeeActivity not in ('CATA','EPA'); */
            /* DREID - Old Code
                          select api.udt_Object(x.FeeId)
                               bulk collect into a_Objects
                               from
                               (select f.FeeId,
                                       substr(f.Description,(instr(f.Description,' ',1,2)+1)) description
                                     from api.Fees f
                                     where f.JobId = a_JobId)x
                                where x.description not in ('CATA','EPA');
                     */
            SELECT api.udt_object(f.feeid)
              BULK COLLECT INTO a_objects
              FROM api.fees f
                   JOIN api.registeredexternalobjects reo
                   ON reo.linkvalue = TO_CHAR(f.feeid)
                  AND reo.objectdefid = t_feeobjdefid
                   JOIN query.r_feelicensefeeschedule r
                   ON r.feeobjectid = reo.objectid
                   JOIN sitespecific.feeschedule_t fs
                   ON fs.objectid = r.licensefeescheduleid
                  AND fs.feeactivity NOT IN ('CATA', 'EPA')
             WHERE f.jobid = a_jobid;
        ELSIF t_cataepa = 'Y' THEN
            IF (a_startdate IS NOT NULL
            AND t_enddate IS NOT NULL) THEN
                SELECT api.udt_object(f.feeid)
                  BULK COLLECT INTO a_objects
                  FROM api.fees f
                       JOIN api.registeredexternalobjects reo
                       ON reo.linkvalue = TO_CHAR(f.feeid)
                      AND reo.objectdefid = t_feeobjdefid
                       JOIN query.r_feelicensefeeschedule r
                       ON r.feeobjectid = reo.objectid
                       JOIN sitespecific.feeschedule_t fs
                       ON fs.objectid = r.licensefeescheduleid
                      AND fs.feeactivity IN ('CATA', 'EPA')
                 WHERE f.jobid = a_jobid
                   AND ((  f.amount
                         + NVL((SELECT SUM(amount)
                                  FROM api.feetransactions ft
                                 WHERE ft.feeid = f.feeid),
                               0)) > 0
                     OR f.transactiondate BETWEEN a_startdate AND t_enddate);
            ELSIF (a_startdate IS NOT NULL) THEN
                SELECT api.udt_object(f.feeid)
                  BULK COLLECT INTO a_objects
                  FROM api.fees f
                       JOIN api.registeredexternalobjects reo
                       ON reo.linkvalue = TO_CHAR(f.feeid)
                      AND reo.objectdefid = t_feeobjdefid
                       JOIN query.r_feelicensefeeschedule r
                       ON r.feeobjectid = reo.objectid
                       JOIN sitespecific.feeschedule_t fs
                       ON fs.objectid = r.licensefeescheduleid
                      AND fs.feeactivity IN ('CATA', 'EPA')
                 WHERE f.jobid = a_jobid
                   AND ((  f.amount
                         + NVL((SELECT SUM(amount)
                                  FROM api.feetransactions ft
                                 WHERE ft.feeid = f.feeid),
                               0)) > 0
                     OR f.transactiondate >= a_startdate);
            ELSIF (a_enddate IS NOT NULL) THEN
                SELECT api.udt_object(f.feeid)
                  BULK COLLECT INTO a_objects
                  FROM api.fees f
                       JOIN api.registeredexternalobjects reo
                       ON reo.linkvalue = TO_CHAR(f.feeid)
                      AND reo.objectdefid = t_feeobjdefid
                       JOIN query.r_feelicensefeeschedule r
                       ON r.feeobjectid = reo.objectid
                       JOIN sitespecific.feeschedule_t fs
                       ON fs.objectid = r.licensefeescheduleid
                      AND fs.feeactivity IN ('CATA', 'EPA')
                 WHERE f.jobid = a_jobid
                   AND ((  f.amount
                         + NVL((SELECT SUM(amount)
                                  FROM api.feetransactions ft
                                 WHERE ft.feeid = f.feeid),
                               0)) > 0
                     OR f.transactiondate <= a_enddate);
            ELSE
                SELECT api.udt_object(f.feeid)
                  BULK COLLECT INTO a_objects
                  FROM api.fees f
                       JOIN api.registeredexternalobjects reo
                       ON reo.linkvalue = TO_CHAR(f.feeid)
                      AND reo.objectdefid = t_feeobjdefid
                       JOIN query.r_feelicensefeeschedule r
                       ON r.feeobjectid = reo.objectid
                       JOIN sitespecific.feeschedule_t fs
                       ON fs.objectid = r.licensefeescheduleid
                      AND fs.feeactivity IN ('CATA', 'EPA')
                 WHERE f.jobid = a_jobid
                   AND (  f.amount
                        + NVL((SELECT SUM(amount)
                                 FROM api.feetransactions ft
                                WHERE ft.feeid = f.feeid),
                              0)) > 0;
            END IF;

            /* DREID - Old Code
                           select api.udt_Object(f.FeeId)
                             bulk collect into a_Objects
                             from api.Fees f
                             join sitespecific.FeeSchedule_t t on t.ObjectId = sitespecific.pkg_Fees.GetLicFeeSchedulObjId(f.FeeId)
                            where f.JobId = a_JobId
                              and (f.Amount+f.AdjustedAmount+f.PaidAmount > 0
                                   or ((a_StartDate is not null and t_EndDate is not null
                                  and f.TransactionDate between a_StartDate and t_EndDate)
                                  or (a_StartDate is null and t_EndDate is not null
                                  and f.TransactionDate <= t_EndDate)
                                  or (a_StartDate is not null and t_EndDate is null
                                  and f.TransactionDate >= a_StartDate)))
                              and t.FeeActivity in ('CATA','EPA');
                     */
            t_findfees   := api.pkg_constantquery.VALUE('FINDFEES');

            IF a_objects.COUNT > t_findfees THEN
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_findfees
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        END IF;
    END feesforfiltering;

    -------------------------------------
    PROCEDURE findfilteredonedaylicenses(a_objectid                   NUMBER,
                                         a_startdate                  DATE,
                                         a_enddate                    DATE,
                                         a_objects         OUT NOCOPY api.udt_objectlist)
    AS
        t_enddate   DATE;
        t_limit     NUMBER;
    BEGIN
        a_objects   := api.udt_objectlist();
        t_enddate   := TRUNC(a_enddate + 1);
        t_limit     := api.pkg_constantquery.VALUE('ADDRESSRELATIONSHIPS');

        SELECT api.udt_object(o.objectid)
          BULK COLLECT INTO a_objects
          FROM query.r_onedaylicenseeventlicense r
               JOIN query.j_onedaylicense o
               ON o.jobid = r.onedaylicensejobid
         WHERE r.addressobjectid = a_objectid
           AND ((a_startdate IS NOT NULL
             AND t_enddate IS NOT NULL
             AND (a_startdate BETWEEN o.dateofeventfrom AND o.dateofeventto
               OR t_enddate BETWEEN o.dateofeventfrom AND o.dateofeventto
               OR o.dateofeventfrom BETWEEN a_startdate AND t_enddate))
             OR (a_startdate IS NULL
             AND t_enddate IS NOT NULL
             AND (o.dateofeventfrom <= t_enddate
               OR o.dateofeventto <= t_enddate))
             OR (a_startdate IS NOT NULL
             AND t_enddate IS NULL
             AND (o.dateofeventfrom >= a_startdate
               OR o.dateofeventto >= a_startdate)));

        IF a_objects.COUNT > t_limit THEN
            api.pkg_errors.raiseerror(-20000,
                                         'More than '
                                      || t_limit
                                      || ' results were found. Please refine your search criteria.');
        END IF;
    END findfilteredonedaylicenses;

    -------------------------------------

    PROCEDURE findfilteredpayments(a_jobid                      udt_id,
                                   a_startdate                  DATE,
                                   a_enddate                    DATE,
                                   a_cataepa                    VARCHAR2,
                                   a_objects         OUT NOCOPY api.udt_objectlist)
    AS
        t_fees              api.udt_objectlist;
        t_enddate           DATE;
        t_startdate         DATE;
        t_paymentobjdefid   udt_id;
    BEGIN
        t_paymentobjdefid   := api.pkg_configquery.objectdefidforname('o_Payment');
        a_objects           := api.udt_objectlist();
        t_fees              := api.udt_objectlist();

        -- Get the fees
        feesforfiltering(a_jobid,
                         a_startdate,
                         a_enddate,
                         a_cataepa,
                         t_fees);

        -- DREID - Old Code
        --    select /*+ CARDINALITY (f 25) */
        --           api.udt_Object(p.ObjectId)
        --      bulk collect into a_Objects
        --      from table(t_Fees) f
        --      join api.FeeTransactions ft on ft.FeeId = f.ObjectId
        --      join api.PaymentTransactions pt on pt.TransactionId = ft.TransactionId
        --      join table(cast(api.pkg_SimpleSearch.CastableObjectsByIndex('o_Payment','PaymentId',pt.PaymentId)as api.udt_ObjectList)) p on 1=1;
        --
        SELECT api.udt_object(reo.objectid)
          BULK COLLECT INTO a_objects
          FROM TABLE(t_fees) f
               JOIN api.feetransactions ft
               ON ft.feeid = f.objectid
               JOIN api.paymenttransactions pt
               ON pt.transactionid = ft.transactionid
               JOIN api.registeredexternalobjects reo
               ON reo.linkvalue = TO_CHAR(pt.paymentid)
              AND reo.objectdefid = t_paymentobjdefid;
    END findfilteredpayments;

    PROCEDURE findfilteredpaytrans(a_jobid                      udt_id,
                                   a_startdate                  DATE,
                                   a_enddate                    DATE,
                                   a_cataepa                    VARCHAR2,
                                   a_objects         OUT NOCOPY api.udt_objectlist)
    AS
        t_fees              api.udt_objectlist;
        t_enddate           DATE;
        t_startdate         DATE;
        t_paytranobjdefid   udt_id;
    BEGIN
        t_paytranobjdefid   := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
        a_objects           := api.udt_objectlist();
        t_fees              := api.udt_objectlist();

        -- Get the fees
        feesforfiltering(a_jobid,
                         a_startdate,
                         a_enddate,
                         a_cataepa,
                         t_fees);

        -- DREID - Old Code
        --    select /*+ CARDINALITY (f 25) */
        --           api.udt_Object(pt.ObjectId)
        --      bulk collect into a_Objects
        --      from table(t_Fees) f
        --      join api.FeeTransactions ft on ft.FeeId = f.ObjectId
        --      join table(cast(api.pkg_SimpleSearch.CastableObjectsByIndex('o_PaymentTransactions','TransactionId',ft.TransactionId)as api.udt_ObjectList)) pt on 1=1;
        --
        SELECT api.udt_object(reo.objectid)
          BULK COLLECT INTO a_objects
          FROM TABLE(t_fees) f
               JOIN api.feetransactions ft
               ON ft.feeid = f.objectid
               JOIN api.registeredexternalobjects reo
               ON reo.linkvalue = TO_CHAR(ft.transactionid)
              AND reo.objectdefid = t_paytranobjdefid;
    END findfilteredpaytrans;

    ----------------------------------------------------------------------------------------------------
    --  FindHold() -- PUBLIC
    --  Used by Outrider for Hold Search
    ----------------------------------------------------------------------------------------------------
    PROCEDURE findhold(a_holdcomment                VARCHAR2,
                       a_holdtype                   VARCHAR2,
                       a_createddate                DATE,
                       a_createddateupper           DATE,
                       a_holduntil                  DATE,
                       a_holduntilto                DATE,
                       a_holdreleased               DATE,
                       a_holdreleasedto             DATE,
                       a_createdby                  VARCHAR2,
                       a_holdstatus                 VARCHAR2,
                       a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_findhold            NUMBER(9, 0);
        t_count               NUMBER(9, 0);
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_findhold            := api.pkg_constantquery.VALUE('FINDHOLD');

        extension.pkg_cxproceduralsearch.initializesearch('o_Hold');
        extension.pkg_cxproceduralsearch.searchbykeywords(a_holdcomment);
        extension.pkg_cxproceduralsearch.searchbyindex('HoldType',
                                                       a_holdtype,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('HoldCreatedDate', a_createddate, a_createddateupper);
        extension.pkg_cxproceduralsearch.searchbyindex('HoldUntil', a_holduntil, a_holduntilto);
        extension.pkg_cxproceduralsearch.searchbyindex('CreatedBy',
                                                       a_createdby,
                                                       NULL,
                                                       FALSE);

        IF a_holdstatus = 'Unreleased' THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_IsNotReleased',
                                                           'Y',
                                                           NULL,
                                                           FALSE);
        ELSIF a_holdstatus = 'Released' THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_IsNotReleased',
                                                           'N',
                                                           NULL,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.searchbyindex('HoldReleased', a_holdreleased, a_holdreleasedto);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        t_count               := t_unfilteredobjects.COUNT;

        IF t_count <= t_findhold THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findhold
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
    END findhold;

    ----------------------------------------------------------------------------------------------------
    --  FindInvestigation() -- PUBLIC
    --  Find Investigation Jobs
    ----------------------------------------------------------------------------------------------------
    PROCEDURE findinvestigation(a_investigationnumber        VARCHAR2,
                                a_abcreportnumber            VARCHAR2,
                                a_citationnumber             VARCHAR2,
                                a_investigationtype          VARCHAR2,
                                a_violationtype              VARCHAR2,
                                a_administrativetype         VARCHAR2,
                                a_name                       VARCHAR2,
                                a_licensenumber              VARCHAR2,
                                a_unlicensed                 VARCHAR2,
                                a_addressline1               VARCHAR2,
                                a_city                       VARCHAR2,
                                a_state                      VARCHAR2,
                                a_zipcode                    VARCHAR2,
                                a_status                     VARCHAR2,
                                a_createdstartdate           DATE,
                                a_createdenddate             DATE,
                                a_completedstartdate         DATE,
                                a_completedenddate           DATE,
                                a_arrestfirstname            VARCHAR2,  -- 6/8/2014 Added by Sheik for WO#9446 Search by Arrest Names
                                a_arrestlastname             VARCHAR2,  -- 6/8/2014 Added by Sheik for WO#9446 Search by Arrest Names
                                a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_status              VARCHAR2(6);
        t_currentuserid       udt_id;
        t_users               udt_idlist;
        t_objectlist          api.udt_objectlist;
        t_findinvestigation   NUMBER(9, 0);
        t_count               NUMBER(9, 0);
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_objectlist          := api.udt_objectlist();
        t_findinvestigation   := api.pkg_constantquery.VALUE('FINDINVESTIGATION');

        IF (a_name IS NOT NULL
        AND a_investigationnumber IS NULL
        AND a_abcreportnumber IS NULL
        AND a_citationnumber IS NULL
        AND a_investigationtype IS NULL
        AND a_violationtype IS NULL
        AND a_administrativetype IS NULL
        AND a_licensenumber IS NULL
        AND a_unlicensed IS NULL
        AND a_addressline1 IS NULL
        AND a_city IS NULL
        AND a_state IS NULL
        AND a_zipcode IS NULL
        AND a_status IS NULL
        AND a_createdstartdate IS NULL
        AND a_createdenddate IS NULL
        AND a_completedstartdate IS NULL
        AND a_completedenddate IS NULL
        AND a_arrestfirstname IS NULL
        AND  -- 6/8/2014 Added by Sheik for WO#9446 Search by Arrest Names
            a_arrestlastname IS NULL  -- 6/8/2014 Added by Sheik for WO#9446 Search by Arrest Names
                                    ) THEN
            api.pkg_errors.raiseerror(-20000, 'When searching by investigator, other criteria must be entered.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('j_Investigation');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     t_status,
                                                     a_createdstartdate,
                                                     a_createdenddate,
                                                     NULL,
                                                     NULL,
                                                     a_completedstartdate,
                                                     a_completedenddate);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_InvestigationNumber',
                                                       a_investigationnumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('ABCReportNumber',
                                                       a_abcreportnumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('ArrestCitation',
                                                              'CitationNumber',
                                                              a_citationnumber,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('ArrestCitation',
                                                              'FirstName',
                                                              a_arrestfirstname,
                                                              NULL,
                                                              TRUE);  -- 6/8/2014 Added by Sheik for WO#9446 Search by Arrest Names
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('ArrestCitation',
                                                              'LastName',
                                                              a_arrestlastname,
                                                              NULL,
                                                              TRUE);  -- 6/8/2014 Added by Sheik for WO#9446 Search by Arrest Names
        extension.pkg_cxproceduralsearch.searchbyindex('InvestigationType',
                                                       a_investigationtype,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('AdministrativeType',
                                                       a_administrativetype,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('ComplaintType',
                                                       a_violationtype,
                                                       NULL,
                                                       FALSE);

        IF a_unlicensed = 'Y' THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_IsUnlicensedInvestigation',
                                                           a_unlicensed,
                                                           NULL,
                                                           FALSE);
        ELSE
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                                  'ExternalFileNum',
                                                                  a_licensenumber,
                                                                  NULL,
                                                                  FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_addressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_city,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USAState',
                                                              a_state,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_zipcode,
                                                              NULL,
                                                              TRUE);

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        -- Filter jobs found by investigator
        IF a_name IS NOT NULL THEN
            t_users               :=
                api.pkg_simplesearch.objectsbykeywords('Users',
                                                          a_name
                                                       || '%');

            FOR r IN 1 .. t_users.COUNT
            LOOP
                t_currentuserid   := t_users(r);

                FOR c IN (SELECT j.objectid jobid
                            FROM TABLE(t_unfilteredobjects) j
                                 JOIN query.p_conductenforcementinv p
                                 ON p.jobid = j.objectid
                                 JOIN api.processassignments pa
                                 ON pa.processid = p.processid
                           WHERE pa.userid = t_currentuserid)
                LOOP
                    t_objectlist.EXTEND(1);
                    t_objectlist(t_objectlist.COUNT)   := api.udt_object(c.jobid);
                END LOOP;
            END LOOP;

            t_unfilteredobjects   := t_objectlist;
        END IF;

        t_count               := t_unfilteredobjects.COUNT;

        IF t_count <= t_findinvestigation THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findinvestigation
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
        t_objectlist.delete;
    END findinvestigation;

    -- ************************************************************************
    -- 10/06/2020 TJL  WO 22281 New version of findjobpayment.
    -- ************************************************************************
    PROCEDURE findjobpayment(a_dup_licensenumber          VARCHAR2,
                             a_paymentdate                DATE,
                             a_paymentdateupper           DATE,
                             a_dup_receiptnumber          VARCHAR2,
                             a_batchid                    VARCHAR2,
                             a_objectdefname              VARCHAR2,
                             a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_filteredobjects       api.udt_objectlist;
        t_accountinguser        VARCHAR(2);
        t_counttransndeps       NUMBER;
        t_paytransobjectdefid   api.pkg_definition.udt_id
                                    := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_filteredobjects   := api.udt_objectlist();

        --Check my Access Groups.
        SELECT DECODE(COUNT(1), 0, 'N', 'Y') hqaccounting
          INTO t_accountinguser
          FROM api.accessgroupusers agu
               JOIN api.accessgroups ag
               ON ag.accessgroupid = agu.accessgroupid
         WHERE agu.userid = api.pkg_securityquery.effectiveuserid()
           AND agu.accessgroupid IN (SELECT accessgroupid
                                       FROM api.accessgroups ag
                                      WHERE ag.description IN ('HQ Accounting', 'Super Users'));

        extension.pkg_cxproceduralsearch.initializesearch('o_Payment');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                          '%'
                                                       || a_dup_licensenumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentDateStored', a_paymentdate, a_paymentdateupper);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ReceiptNumber',
                                                       a_dup_receiptnumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('BatchPaymentId',
                                                       UPPER(a_batchid),
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        -- pre process unfiltered object list
        --  remove payments that are not associated with this license number.  Search will
        --  return payment that the passed in license number is part of the payment license
        --  number. Passed in license number 123 will have payment records from license
        --  numbers 123, 601123, 1230, 12300, 123000.  
        --    Search acts like a like search (LicenseNumber LIKE '%123%')
        FOR rec IN (SELECT u.objectid, api.pkg_columnquery.VALUE(u.objectid, 'dup_LicenseNumber') dup_licensenumber
                      FROM TABLE(t_unfilteredobjects) u)
        LOOP
            -- a single payment record can be associated to more than one license.  If payment
            --  record has more than one license, the license numbers are returned in a comma
            --  seprated list.
            FOR rec2 IN (    SELECT TRIM(REGEXP_SUBSTR(rec.dup_licensenumber,
                                                       '[^,]+',
                                                       1,
                                                       LEVEL))
                                        dup_licensenumber
                               FROM DUAL
                         CONNECT BY REGEXP_SUBSTR(rec.dup_licensenumber,
                                                  '[^,]+',
                                                  1,
                                                  LEVEL)
                                        IS NOT NULL)
            LOOP
                -- check if payment is associated with passed in license number
                IF (rec2.dup_licensenumber = a_dup_licensenumber) THEN
                    DBMS_OUTPUT.put_line(   'payment object id: '
                                         || rec.objectid);
                    t_filteredobjects.EXTEND(1);
                    t_filteredobjects(t_filteredobjects.COUNT)   := api.udt_object(rec.objectid);
                END IF;
            END LOOP;
        END LOOP;

        FOR p IN (WITH
                      rec
                      AS
                          (  SELECT  /*+ materialize */
                                    api.pkg_columnquery.VALUE(reo.objectid, 'CABINAmtType') cabinamttype,
                                    api.pkg_columnquery.VALUE(reo.objectid, 'FeeObjId')     feeobjid,
                                    p.objectid                                              paymentobjectid,
                                    api.pkg_columnquery.VALUE(reo.objectid, 'IsRefunded')   isrefunded,
                                    api.pkg_columnquery.VALUE(p.objectid, 'IsRefundReversed') isrefundreversed,
                                    api.pkg_columnquery.VALUE(p.objectid, 'PaymentAmountR') amount,
                                    api.pkg_columnquery.VALUE(p.objectid, 'PaymentAmount')  paymentamount
                               FROM TABLE(t_filteredobjects) u
                                    JOIN query.o_payment p
                                    ON u.objectid = p.objectid
                                    JOIN api.paymenttransactions pts
                                    ON p.paymentid = pts.paymentid
                                    JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                    ON reo.linkvalue = TO_CHAR(pts.transactionid)
                                   AND reo.objectdefid = t_paytransobjectdefid
                                    JOIN api.feetransactions ft
                                    ON ft.transactionid = pts.transactionid
                              WHERE api.pkg_columnquery.VALUE(reo.objectid, 'VoidedByTransactionId') IS NULL
                                AND p.isdishonored = 'N'
                                AND p.isrefund = 'N'
                                AND api.pkg_columnquery.VALUE(reo.objectid, 'IsServiceCharge') = 'N'
                                AND p.objectid NOT IN (SELECT DISTINCT (o.objectid)
                                                         FROM query.o_payment p2
                                                              JOIN api.paymenttransactions pts
                                                              ON p2.paymentid = pts.paymentid
                                                              JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                                              ON reo.linkvalue = TO_CHAR(pts.transactionid)
                                                             AND reo.objectdefid = t_paytransobjectdefid
                                                              JOIN api.objects o
                                                              ON o.objectid = reo.objectid
                                                              JOIN query.r_paymenttransfertrans rpt
                                                              ON rpt.paymenttransactionobjectid = reo.objectid  --APatterson: PIP Task 8.5
                                                        WHERE p2.objectid = p.objectid  --t_unfilteredobjects(c).objectid
                                                          AND (rpt.feeamountstored + rpt.amount) != 0)
                           ORDER BY feeobjid, paymentobjectid)
                  SELECT DISTINCT r1.paymentobjectid
                    FROM rec r1
                   WHERE (r1.cabinamttype IN ('I', 'C')
                      AND amount > 0
                      AND api.pkg_columnquery.VALUE(r1.feeobjid, 'PaidAmount') != 0
                      AND r1.isrefunded = 'N')
                      OR (r1.cabinamttype = 'R'
                      AND r1.isrefundreversed = 'N'
--                      AND NOT EXISTS
--                              (SELECT 1
--                                 FROM rec r2
--                                WHERE r1.feeobjid = r2.feeobjid
--                                  AND r2.isrefundreversed = 'Y')
                         ))
        LOOP
            SELECT SUM(cnts)
              INTO t_counttransndeps
              FROM (SELECT COUNT(1) cnts
                      FROM query.r_transmittalpayment tp
                     WHERE tp.paymentobjectid = p.paymentobjectid
                    UNION ALL
                    SELECT COUNT(1)
                      FROM query.r_paymentbatchpayment pbp
                     WHERE pbp.paymentobjectid = p.paymentobjectid);

            IF ((t_counttransndeps = 0
             AND t_accountinguser = 'N')
             OR t_accountinguser = 'Y') THEN
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(p.paymentobjectid);
            END IF;
        END LOOP;

        t_unfilteredobjects.delete;
        t_filteredobjects.delete;
    END findjobpayment;

    -- ************************************************************************
    -- 10/06/2020 TJL  WO 22281 Replaced current version with new version. Kept
    --                           old version for reference not used any more.
    -- ************************************************************************
    PROCEDURE findjobpayment_obsolete(a_dup_licensenumber          VARCHAR2,
                                      a_paymentdate                DATE,
                                      a_paymentdateupper           DATE,
                                      a_dup_receiptnumber          VARCHAR2,
                                      a_batchid                    VARCHAR2,
                                      a_objectdefname              VARCHAR2,
                                      a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects      api.udt_objectlist;
        t_feeamount              NUMBER;
        t_objdefname             VARCHAR2(30) := a_objectdefname;
        t_maxservicechargebool   VARCHAR(2);
        t_accountinguser         VARCHAR(2);
        t_counttransndeps        NUMBER;
        t_paytransobjectdefid    udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        --Check my Access Groups.
        SELECT DECODE(COUNT(1), 0, 'N', 'Y') hqaccounting
          INTO t_accountinguser
          FROM api.accessgroupusers agu
               JOIN api.accessgroups ag
               ON ag.accessgroupid = agu.accessgroupid
         WHERE agu.userid = api.pkg_securityquery.effectiveuserid()
           AND agu.accessgroupid IN (SELECT accessgroupid
                                       FROM api.accessgroups ag
                                      WHERE ag.description IN ('HQ Accounting', 'Super Users'));

        extension.pkg_cxproceduralsearch.initializesearch('o_Payment');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                          '%'
                                                       || a_dup_licensenumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentDateStored', a_paymentdate, a_paymentdateupper);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ReceiptNumber',
                                                       a_dup_receiptnumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('BatchPaymentId',
                                                       UPPER(a_batchid),
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF a_objectdefname IS NULL THEN
            t_objdefname   := 'empty';
        END IF;

        FOR c IN 1 .. t_unfilteredobjects.COUNT
        LOOP
            --Get Fee Amount for
            SELECT SUM(ft.amount), MAX(api.pkg_columnquery.VALUE(reo.objectid, 'IsServiceCharge'))
              INTO t_feeamount, t_maxservicechargebool
              FROM query.o_payment p
                   JOIN api.paymenttransactions pts
                   ON p.paymentid = pts.paymentid
                   JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                   ON reo.linkvalue = TO_CHAR(pts.transactionid)
                  AND reo.objectdefid = t_paytransobjectdefid
                   JOIN api.feetransactions ft
                   ON ft.transactionid = pts.transactionid  --APatterson: PIP Task 8.5 --api.pkg_ColumnQuery.NumericValue(reo.ObjectId,'TransactionId')
             WHERE p.objectid = t_unfilteredobjects(c).objectid
               AND api.pkg_columnquery.VALUE(reo.objectid, 'VoidedByTransactionId') IS NULL
               AND p.isdishonored = 'N'
               AND p.objectid NOT IN (SELECT DISTINCT (o.objectid)
                                        FROM query.o_payment p
                                             JOIN api.paymenttransactions pts
                                             ON p.paymentid = pts.paymentid
                                             JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                             ON reo.linkvalue = TO_CHAR(pts.transactionid)
                                            AND reo.objectdefid = t_paytransobjectdefid
                                             JOIN api.objects o
                                             ON o.objectid = reo.objectid
                                             JOIN query.r_paymenttransfertrans rpt
                                             ON rpt.paymenttransactionobjectid = reo.objectid  --APatterson: PIP Task 8.5
                                       WHERE p.objectid = t_unfilteredobjects(c).objectid
                                         AND (rpt.movefrom = 'Y'))  -- MM894
                                                                  --and ft.amount < 0
                                                                  ;

            SELECT SUM(cnts)
              INTO t_counttransndeps
              FROM (SELECT COUNT(1) cnts
                      FROM query.r_transmittalpayment tp
                     WHERE tp.paymentobjectid = t_unfilteredobjects(c).objectid
                    UNION ALL
                    SELECT COUNT(1)
                      FROM query.r_paymentbatchpayment pbp
                     WHERE pbp.paymentobjectid = t_unfilteredobjects(c).objectid) data;

            IF ((t_feeamount < 0
             AND t_maxservicechargebool = 'N')
             OR (t_feeamount > 0
             AND t_maxservicechargebool = 'Y')
             OR (t_feeamount < 0
             AND t_maxservicechargebool = 'Y'))  -- added to include/Process SRV payments in ABIS, without going through Posse Batch refund -- Gurpreet (May_22_2013)
           AND api.pkg_columnquery.VALUE(t_unfilteredobjects(c).objectid, 'IsRefund') = 'N'
           AND ((t_counttransndeps = 0
             AND t_accountinguser = 'N')
             OR t_accountinguser = 'Y') THEN
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(t_unfilteredobjects(c).objectid);
            END IF;
        END LOOP;

        t_unfilteredobjects.delete;
    END findjobpayment_obsolete;

    /**************************************************************************************************
        * FindLegalEntity() -- PUBLIC
        *   Called by Outrider to find Legal Entity objects
        **************************************************************************************************/
    PROCEDURE findlegalentity(a_name                       VARCHAR2,
                              a_addressline1               VARCHAR2,
                              a_uscity                     VARCHAR2,
                              a_usstate                    VARCHAR2,
                              a_zipcode                    NUMBER,
                              a_relatedjoblicno            VARCHAR2,
                              a_hierarchylevel             VARCHAR2,
                              a_socialsecurityno           VARCHAR2, --NUMBER,
                              a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects      api.udt_objectlist;
        t_filteredobjectidlist   udt_idlist;
        t_keywordobjectlist      api.udt_objectlist;
        t_searchperformed        BOOLEAN;
        t_findlegalentity        NUMBER(9, 0);
        t_count                  NUMBER(9, 0);
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_keywordobjectlist   := api.udt_objectlist();

        t_findlegalentity     := api.pkg_constantquery.VALUE('FINDLEGALENTITY');

        extension.pkg_cxproceduralsearch.initializesearch('o_LegalEntity');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonAddress',
                                                              'AddressLine1',
                                                              a_addressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonAddress',
                                                              'USACity',
                                                              a_uscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonAddress',
                                                              'USAState',
                                                              a_usstate,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonAddress',
                                                              'ZipCode',
                                                              a_zipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_RelatedJobLicNo',
                                                       a_relatedjoblicno,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Person',
                                                              'SocialSecurityNumber',
                                                              a_socialsecurityno,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('o_LegalEntity');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyAddress',
                                                              'AddressLine1',
                                                              a_addressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyAddress',
                                                              'USACity',
                                                              a_uscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyAddress',
                                                              'USAState',
                                                              a_usstate,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyAddress',
                                                              'ZipCode',
                                                              a_zipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_RelatedJobLicNo',
                                                       a_relatedjoblicno,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        t_searchperformed     :=
            a_addressline1 IS NOT NULL
         OR a_uscity IS NOT NULL
         OR a_usstate IS NOT NULL
         OR a_zipcode IS NOT NULL
         OR a_relatedjoblicno IS NOT NULL
         OR a_socialsecurityno IS NOT NULL;

        -- Search by Name entered
        IF a_name IS NOT NULL THEN
            t_keywordobjectlist   := api.udt_objectlist();

            -- Get all objects with this Name as a keyword and convert it to an ObjectList for use in select
            extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                 api.pkg_simplesearch.objectsbykeywords('o_Person',
                                                                                           a_name
                                                                                        || '%'));
            extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                 api.pkg_simplesearch.objectsbykeywords('o_Company',
                                                                                           a_name
                                                                                        || '%'));

            -- Find all Legal Entity related to this Company or Person
            SELECT lep.legalentityobjectid
              BULK COLLECT INTO t_filteredobjectidlist
              FROM TABLE(t_keywordobjectlist) source
                   JOIN query.r_legalentityperson lep
                   ON lep.personobjectid = source.objectid
            UNION ALL
            SELECT lec.legalentityobjectid
              FROM TABLE(t_keywordobjectlist) source
                   JOIN query.r_legalentitycompany lec
                   ON lec.companyobjectid = source.objectid;

            -- Put results into the main list of found objects
            IF t_searchperformed THEN
                extension.pkg_collectionutils.join(t_unfilteredobjects, t_filteredobjectidlist);
            ELSE
                extension.pkg_collectionutils.append(t_unfilteredobjects, t_filteredobjectidlist);
            END IF;
        END IF;

        IF a_hierarchylevel IS NOT NULL THEN
            FOR i IN 1 .. t_unfilteredobjects.COUNT
            LOOP
                IF api.pkg_columnquery.VALUE(t_unfilteredobjects(i).objectid, 'dup_HierarchyLevel') =
                   a_hierarchylevel THEN
                    a_objects.EXTEND(1);
                    a_objects(a_objects.COUNT)   := t_unfilteredobjects(i);
                END IF;
            END LOOP;
        ELSE
            a_objects   := t_unfilteredobjects;
        END IF;

        t_count               := t_unfilteredobjects.COUNT;

        IF t_count > t_findlegalentity THEN
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findlegalentity
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
    END findlegalentity;

    /**************************************************************************************************
        * FindLegalEntityNonP12() -- PUBLIC
        *   Called by Outrider to find Legal Entity objects which are not P12 entities
        **************************************************************************************************/
    PROCEDURE findlegalentitynonp12(a_name                       VARCHAR2,
                                    a_addressline1               VARCHAR2,
                                    a_uscity                     VARCHAR2,
                                    a_usstate                    VARCHAR2,
                                    a_zipcode                    NUMBER,
                                    a_relatedjoblicno            VARCHAR2,
                                    a_hierarchylevel             VARCHAR2,
                                    a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        findlegalentity(a_name,
                        a_addressline1,
                        a_uscity,
                        a_usstate,
                        a_zipcode,
                        a_relatedjoblicno,
                        a_hierarchylevel,
                        NULL,
                        t_unfilteredobjects);

        FOR c IN 1 .. t_unfilteredobjects.COUNT
        LOOP
            -- Filter out all of the P12 Results
            IF api.pkg_columnquery.VALUE(t_unfilteredobjects(c).objectid, 'P12Status') = 'N' THEN
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := t_unfilteredobjects(c);
            END IF;
        END LOOP;

        t_unfilteredobjects.delete;
    END findlegalentitynonp12;

    ----------------------------------------------------------------------------------------------------
    --  FindLicAndAppAccHistory() -- PUBLIC
    --  Used by Outrider to Search for Licenses and Application (under label License)
    --  Procedure limits based off of dynamic detail IncludeInAccHistorySearch on Application.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE findlicandappacchistory(a_externalfilenum VARCHAR2, a_objects OUT NOCOPY api.udt_objectlist)
    IS
        t_applicationobjects        api.udt_objectlist;
        t_licenseobjects            api.udt_objectlist;
        t_findlicandappacchistory   NUMBER(9, 0);
        t_count                     NUMBER(9, 0);
    BEGIN
        a_objects                   := api.udt_objectlist();
        t_applicationobjects        := api.udt_objectlist();
        t_licenseobjects            := api.udt_objectlist();
        t_findlicandappacchistory   := api.pkg_constantquery.VALUE('FINDLICANDAPPACCHISTORY');

        --when there is a License return that ObjectId, if however there is not a License return the ObjectId of the Application.
        extension.pkg_cxproceduralsearch.initializesearch('j_Application');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                       a_externalfilenum,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IncludeInAccHistorySearch',
                                                       'Y',
                                                       NULL,
                                                       NULL);
        extension.pkg_cxproceduralsearch.performsearch(t_applicationobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('j_License');
        extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                       a_externalfilenum,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_licenseobjects, 'and', 'none');

        --Combine t_ApplicationObjects and t_LicenseObjects.
        extension.pkg_collectionutils.append(t_applicationobjects, t_licenseobjects);

        t_count                     := t_applicationobjects.COUNT;

        IF t_count <= t_findlicandappacchistory THEN
            a_objects   := t_applicationobjects;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findlicandappacchistory
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_applicationobjects.delete;
        t_licenseobjects.delete;
    END findlicandappacchistory;

    PROCEDURE findlicense(a_externalfilenum            VARCHAR2,
                          a_licenseenames              VARCHAR2,
                          a_dup_premaddressline1       VARCHAR2,
                          a_dup_premaddressuscity      VARCHAR2,
                          a_dup_premzipcode            VARCHAR2,
                          a_dup_dbas                   VARCHAR2,
                          a_createddate                DATE,
                          a_createddateupper           DATE,
                          a_status                     VARCHAR2,
                          a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('j_License');

        IF a_createddate IS NOT NULL
        OR a_createddateupper IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         a_createddate,
                                                         a_createddateupper,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL);
        END IF;

        IF a_externalfilenum IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                           a_externalfilenum,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_dup_premaddressline1 IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'AddressLine1',
                                                                  a_dup_premaddressline1,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_premaddressuscity IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'USACity',
                                                                  a_dup_premaddressuscity,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_premzipcode IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'ZipCode',
                                                                  a_dup_premzipcode,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_dbas IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                                  'DBA',
                                                                  a_dup_dbas,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF a_licenseenames IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.initializesearch('j_License');
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonLicensee',
                                                                  'dup_FormattedPersonNameSearch',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyLicensee',
                                                                  'CompanyName',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12PersonLicensee',
                                                                  'dup_FormattedPersonNameSearch',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12CompanyLicensee',
                                                                  'CompanyName',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);

            IF t_unfilteredobjects.FIRST IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'and');
            ELSIF t_unfilteredobjects.FIRST IS NULL THEN
                extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'or', 'or');
            END IF;
        END IF;

        a_objects             := t_unfilteredobjects;
        t_unfilteredobjects.delete;
    END findlicense;

    /**************************************************************************************************
        * FindLicenseAndApplication() -- PUBLIC
        *   Used by Outrider to Search for Licenses and Application (under label License)
        *   User needs to select Status Description, but SearchByJob procedure only takes StatusName.
        **************************************************************************************************/
    PROCEDURE findlicenseandapplication(a_externalfilenum            VARCHAR2,
                                        a_regnumber                  VARCHAR2,
                                        a_licenseenames              VARCHAR2,
                                        a_premaddressline1           VARCHAR2,
                                        a_premaddressline2           VARCHAR2,
                                        a_premuscity                 VARCHAR2,
                                        a_premzipcode                VARCHAR2,
                                        a_dup_dbas                   VARCHAR2,
                                        a_createddate                DATE,
                                        a_createddateupper           DATE,
                                        a_status                     VARCHAR2,
                                        a_override                   VARCHAR2,
                                        a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_applicationobjects          api.udt_objectlist;
        t_licenseobjects              api.udt_objectlist;
        t_filteredobjectids           api.udt_objectlist;
        t_regnumberobjectids          api.udt_objectlist;
        t_filteredobjectidlist        udt_idlist;
        t_keywordobjectlist           api.udt_objectlist;
        t_status                      VARCHAR2(6);
        t_appstatus                   CHAR := 'Y';
        t_licstatus                   CHAR := 'Y';
        t_islictypestatus             VARCHAR2(1);
        t_findlicenseandapplication   NUMBER(9, 0);
        t_count                       NUMBER(9, 0);
        t_searchperformed             BOOLEAN;
    BEGIN
        a_objects                     := api.udt_objectlist();
        t_applicationobjects          := api.udt_objectlist();
        t_licenseobjects              := api.udt_objectlist();
        t_filteredobjectids           := api.udt_objectlist();
        t_findlicenseandapplication   := api.pkg_constantquery.VALUE('FindLicenseAndApplication');

        IF (a_status IS NOT NULL
        AND a_externalfilenum IS NULL
        AND a_regnumber IS NULL
        AND a_licenseenames IS NULL
        AND a_premaddressline1 IS NULL
        AND a_premaddressline2 IS NULL
        AND a_premuscity IS NULL
        AND a_premzipcode IS NULL
        AND a_dup_dbas IS NULL
        AND a_createddate IS NULL
        AND a_createddateupper IS NULL) THEN
            api.pkg_errors.raiseerror(
                -20000,
                'Please supply additional search criteria.  Searching only by Status will return too many rows.');
        END IF;

        -- not the best way to handle this.
        -- User needs to select Status Description, but SearchByJob procedure only takes StatusName.
        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;

            --check which jobs are valid for the status
            SELECT NVL(MAX('Y'), 'N')
              INTO t_appstatus
              FROM api.statuses st
                   JOIN api.jobstatuses js
                   ON js.statusid = st.statusid
             WHERE st.description = a_status
               AND js.jobtypeid = api.pkg_configquery.objectdefidforname('j_Application');

            SELECT NVL(MAX('Y'), 'N')
              INTO t_licstatus
              FROM api.statuses st
                   JOIN api.jobstatuses js
                   ON js.statusid = st.statusid
             WHERE st.description = a_status
               AND js.jobtypeid = api.pkg_configquery.objectdefidforname('j_LicenseType');
        END IF;

        IF t_appstatus = 'Y' THEN
            extension.pkg_cxproceduralsearch.initializesearch('j_Application');

            IF t_status IS NOT NULL
            OR a_createddate IS NOT NULL
            OR a_createddateupper IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                             NULL,
                                                             NULL,
                                                             t_status,
                                                             a_createddate,
                                                             a_createddateupper,
                                                             NULL,
                                                             NULL,
                                                             NULL,
                                                             NULL);
            END IF;

            IF a_externalfilenum IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                               a_externalfilenum,
                                                               NULL,
                                                               FALSE);
            END IF;

            IF a_regnumber IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyindex('RegNumber',
                                                               a_regnumber,
                                                               NULL,
                                                               TRUE);
            END IF;

            IF a_premaddressline1 IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                      'AddressLine1',
                                                                      a_premaddressline1,
                                                                      NULL,
                                                                      TRUE);
            END IF;
            
              IF a_premaddressline2 IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                      'AddressLine2',
                                                                      a_premaddressline2,
                                                                      NULL,
                                                                      TRUE);
            END IF;


            IF a_premuscity IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                      'USACity',
                                                                      a_premuscity,
                                                                      NULL,
                                                                      TRUE);
            END IF;

            IF a_premzipcode IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                      'ZipCode',
                                                                      a_premzipcode,
                                                                      NULL,
                                                                      TRUE);
            END IF;

            extension.pkg_cxproceduralsearch.performsearch(t_applicationobjects, 'and', 'none');

            t_searchperformed   :=
                a_externalfilenum IS NOT NULL
             OR a_regnumber IS NOT NULL
             OR a_premaddressline1 IS NOT NULL
             OR a_premaddressline2 IS NOT NULL
             OR a_premuscity IS NOT NULL
             OR a_premzipcode IS NOT NULL
             OR a_createddate IS NOT NULL
             OR a_createddateupper IS NOT NULL
             OR a_status IS NOT NULL;

            -- Search for DBAs if DBA Names were entered
            IF a_dup_dbas IS NOT NULL THEN
                t_keywordobjectlist   := api.udt_objectlist();

                -- Get all objects with this Licensee as a keyword and convert it to an ObjectList for use in select
                extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                     api.pkg_simplesearch.objectsbykeywords('o_DBANames',
                                                                                               a_dup_dbas
                                                                                            || '%'));

                -- Find all Applications with this DBA
                SELECT apdba.applicationjobid
                  BULK COLLECT INTO t_filteredobjectidlist
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_applicationdbanames apdba
                       ON apdba.dbanamesobjectid = source.objectid;

                -- Put results into the main list of found objects
                IF t_searchperformed THEN
                    extension.pkg_collectionutils.join(t_applicationobjects, t_filteredobjectidlist);
                ELSE
                    extension.pkg_collectionutils.append(t_applicationobjects, t_filteredobjectidlist);
                END IF;

                t_searchperformed     := TRUE;
            END IF;

            -- Search for Licensees if Licensee Names were entered
            IF a_licenseenames IS NOT NULL THEN
                t_keywordobjectlist   := api.udt_objectlist();

                -- Get all objects with this Licensee as a keyword and convert it to an ObjectList for use in select
                extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                     api.pkg_simplesearch.objectsbykeywords('o_Person',
                                                                                               a_licenseenames
                                                                                            || '%'));
                extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                     api.pkg_simplesearch.objectsbykeywords('o_Company',
                                                                                               a_licenseenames
                                                                                            || '%'));

                -- Find all Applications with this Company or Person as the License
                SELECT aple.applicationobjectid
                  BULK COLLECT INTO t_filteredobjectidlist
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_legalentityperson lep
                       ON lep.personobjectid = source.objectid
                       JOIN query.r_applicationlegalentityapp aple
                       ON aple.legalentityobjectid = lep.legalentityobjectid
                UNION ALL
                SELECT p12le.applicationjobid
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_legalentityperson lep
                       ON lep.personobjectid = source.objectid
                       JOIN query.r_applicationp12legalentity p12le
                       ON p12le.legalentityobjectid = lep.legalentityobjectid
                UNION ALL
                SELECT aple.applicationobjectid
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_legalentitycompany lec
                       ON lec.companyobjectid = source.objectid
                       JOIN query.r_applicationlegalentityapp aple
                       ON aple.legalentityobjectid = lec.legalentityobjectid
                UNION ALL
                SELECT p12le.applicationjobid
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_legalentitycompany lec
                       ON lec.companyobjectid = source.objectid
                       JOIN query.r_applicationp12legalentity p12le
                       ON p12le.legalentityobjectid = lec.legalentityobjectid;

                -- Put results into the main list of found objects
                IF t_searchperformed THEN
                    extension.pkg_collectionutils.join(t_applicationobjects, t_filteredobjectidlist);
                ELSE
                    extension.pkg_collectionutils.append(t_applicationobjects, t_filteredobjectidlist);
                END IF;
            END IF;
        END IF;

        --BEGIN LICENSE (skip when Reg Number criteria is entered)
        IF t_licstatus = 'Y' THEN
            extension.pkg_cxproceduralsearch.initializesearch('j_License');

            IF a_createddate IS NOT NULL
            OR a_createddateupper IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                             NULL,
                                                             NULL,  /*t_Status*/
                                                             NULL,
                                                             a_createddate,
                                                             a_createddateupper,
                                                             NULL,
                                                             NULL,
                                                             NULL,
                                                             NULL);
            END IF;

            /*if a_Status is not null then -- it is a system column
                       extension.pkg_cxproceduralSearch.SearchByRelatedIndex('LicenseType', 'StatusName', t_Status, null, false);
                     end if;*/

            IF a_externalfilenum IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                               a_externalfilenum,
                                                               NULL,
                                                               FALSE);
            END IF;

            IF a_premaddressline1 IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                      'AddressLine1',
                                                                      a_premaddressline1,
                                                                      NULL,
                                                                      TRUE);
            END IF;
            
            
            IF a_premaddressline2 IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                      'AddressLine2',
                                                                      a_premaddressline2,
                                                                      NULL,
                                                                      TRUE);
            END IF;

            IF a_premuscity IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                      'USACity',
                                                                      a_premuscity,
                                                                      NULL,
                                                                      TRUE);
            END IF;

            IF a_premzipcode IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                      'ZipCode',
                                                                      a_premzipcode,
                                                                      NULL,
                                                                      TRUE);
            END IF;

            extension.pkg_cxproceduralsearch.performsearch(t_licenseobjects, 'and', 'none');

            t_searchperformed     :=
                a_externalfilenum IS NOT NULL
             OR a_premaddressline1 IS NOT NULL
             OR a_premaddressline2 IS NOT NULL
             OR a_premuscity IS NOT NULL
             OR a_premzipcode IS NOT NULL
             OR a_createddate IS NOT NULL
             OR a_createddateupper IS NOT NULL;

            -- Search for DBAs if DBA Names were entered
            IF a_dup_dbas IS NOT NULL THEN
                t_keywordobjectlist   := api.udt_objectlist();

                -- Get all objects with this DBA as a keyword and convert it to an ObjectList for use in select
                extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                     api.pkg_simplesearch.objectsbykeywords('o_DBANames',
                                                                                               a_dup_dbas
                                                                                            || '%'));

                -- Find all Licenses with this DBA
                SELECT lidba.licensejobid
                  BULK COLLECT INTO t_filteredobjectidlist
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_licensedbanames lidba
                       ON lidba.dbanamesobjectid = source.objectid;

                -- Put results into the main list of found objects
                IF t_searchperformed THEN
                    extension.pkg_collectionutils.join(t_licenseobjects, t_filteredobjectidlist);
                ELSE
                    extension.pkg_collectionutils.append(t_licenseobjects, t_filteredobjectidlist);
                END IF;

                t_searchperformed     := TRUE;
            END IF;

            -- Search for Licensees if Licensee Names were entered
            IF a_licenseenames IS NOT NULL THEN
                t_keywordobjectlist   := api.udt_objectlist();

                -- Get all objects with this Licensee as a keyword and convert it to an ObjectList for use in select
                extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                     api.pkg_simplesearch.objectsbykeywords('o_Person',
                                                                                               a_licenseenames
                                                                                            || '%'));
                extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                     api.pkg_simplesearch.objectsbykeywords('o_Company',
                                                                                               a_licenseenames
                                                                                            || '%'));

                -- Find all Licenses with this Company or Person as the Licensee
                SELECT lile.licensejobid
                  BULK COLLECT INTO t_filteredobjectidlist
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_legalentityperson lep
                       ON lep.personobjectid = source.objectid
                       JOIN query.r_licenselegalentitylicensee lile
                       ON lile.legalentityobjectid = lep.legalentityobjectid
                UNION ALL
                SELECT p12le.licensejobid
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_legalentityperson lep
                       ON lep.personobjectid = source.objectid
                       JOIN query.r_licensep12legalentity p12le
                       ON p12le.legalentityobjectid = lep.legalentityobjectid
                UNION ALL
                SELECT lile.licensejobid
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_legalentitycompany lec
                       ON lec.companyobjectid = source.objectid
                       JOIN query.r_licenselegalentitylicensee lile
                       ON lile.legalentityobjectid = lec.legalentityobjectid
                UNION ALL
                SELECT p12le.licensejobid
                  FROM TABLE(t_keywordobjectlist) source
                       JOIN query.r_legalentitycompany lec
                       ON lec.companyobjectid = source.objectid
                       JOIN query.r_licensep12legalentity p12le
                       ON p12le.legalentityobjectid = lec.legalentityobjectid;

                -- Put results into the main list of found objects
                IF t_searchperformed THEN
                    extension.pkg_collectionutils.join(t_licenseobjects, t_filteredobjectidlist);
                ELSE
                    extension.pkg_collectionutils.append(t_licenseobjects, t_filteredobjectidlist);
                END IF;
            END IF;

            t_filteredobjectids   := api.udt_objectlist();

            IF a_status IS NOT NULL THEN
                FOR c IN 1 .. t_licenseobjects.COUNT
                LOOP
                    SELECT NVL(MAX('Y'), 'N')
                      INTO t_islictypestatus
                      FROM query.j_license l
                           JOIN query.r_licenselicensetype llt
                           ON llt.licensejobid = l.jobid
                           JOIN query.j_licensetype lt
                           ON lt.jobid = llt.licensetypejobid
                     WHERE l.jobid = t_licenseobjects(c).objectid
                       AND lt.statusname = t_status;

                    IF t_islictypestatus = 'Y' THEN
                        t_filteredobjectids.EXTEND;
                        t_filteredobjectids(t_filteredobjectids.COUNT)   := t_licenseobjects(c);
                    END IF;
                END LOOP;
            ELSE
                t_filteredobjectids   := t_licenseobjects;
            END IF;

            IF a_regnumber IS NOT NULL THEN
                SELECT api.udt_object(t.jobid)
                  BULK COLLECT INTO t_regnumberobjectids
                  FROM (SELECT api.pkg_columnquery.numericvalue(rp.objectid, 'JobId') jobid
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex('p_RegisterProtest',
                                                                                   'RegNumber',
                                                                                   a_regnumber) AS api.udt_objectlist))
                               rp
                        UNION
                        SELECT api.pkg_columnquery.numericvalue(rd.objectid, 'JobId') jobid
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex('p_RegisterDenialHearing',
                                                                                   'RegNumber',
                                                                                   a_regnumber) AS api.udt_objectlist))
                               rd) t;

                IF t_filteredobjectids.FIRST IS NOT NULL THEN
                    extension.pkg_collectionutils.join(t_filteredobjectids, t_regnumberobjectids);
                ELSE
                    extension.pkg_collectionutils.append(t_filteredobjectids, t_regnumberobjectids);
                END IF;
            END IF;

            --Combine t_ApplicationObjects and t_LicenseObjects.
            extension.pkg_collectionutils.append(t_applicationobjects, t_filteredobjectids);
        END IF;

        t_count                       := t_applicationobjects.COUNT;

        IF t_count <= t_findlicenseandapplication
        OR a_override = 'Y' THEN
            a_objects   := t_applicationobjects;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findlicenseandapplication
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_applicationobjects.delete;
        t_licenseobjects.delete;
    END findlicenseandapplication;

    /**************************************************************************************************
        * FindLicenseType() -- PUBLIC
        *   Used by Outrider to Search for License Types
        **************************************************************************************************/
    PROCEDURE findlicensetype(a_dup_licensetypecode        VARCHAR2,
                              a_dup_licensetypename        VARCHAR2,
                              a_dup_licenseexternalfilenum VARCHAR2,
                              a_dup_licenseenames          VARCHAR2,
                              a_dup_licenseaddressline1    VARCHAR2,
                              a_dup_licenseuscity          VARCHAR2,
                              a_dup_licensezipcode         VARCHAR2,
                              a_dup_licensedbas            VARCHAR2,
                              a_createddate                DATE,
                              a_createddateupper           DATE,
                              a_expirationdate             DATE,
                              a_expirationdateupper        DATE,
                              a_status                     VARCHAR2,
                              a_override                   VARCHAR2,
                              a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects            api.udt_objectlist;
        t_secondaryunfilteredobjects   api.udt_objectlist;
        t_secondarycategoryobjects     api.udt_objectlist;
        t_filteredobjectidlist         udt_idlist;
        t_keywordobjectlist            api.udt_objectlist;
        t_status                       VARCHAR2(6);
        t_filterstatus                 VARCHAR2(6);
        t_findlicensetype              NUMBER(9, 0);
        t_count                        NUMBER(9, 0);
        t_searchperformed              BOOLEAN;
    BEGIN
        a_objects                      := api.udt_objectlist();
        t_unfilteredobjects            := api.udt_objectlist();
        t_secondaryunfilteredobjects   := api.udt_objectlist();
        t_secondarycategoryobjects     := api.udt_objectlist();
        t_findlicensetype              := api.pkg_constantquery.VALUE('FindLicenseType');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        --Primary
        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     t_status,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('LicTypeCatPrimary',
                                                              'LicenseTypeCode',
                                                              a_dup_licensetypecode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('LicTypeCatPrimary',
                                                              'LicenseTypeName',
                                                              a_dup_licensetypename,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_dup_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbykeywords(   a_dup_licenseenames
                                                          || '%');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_dup_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_dup_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_dup_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ExpirationDate', a_expirationdate, a_expirationdateupper);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        --Secondary
        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('LicTypeCatSecondary',
                                                              'LicenseTypeCode',
                                                              a_dup_licensetypecode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('LicTypeCatSecondary',
                                                              'LicenseTypeName',
                                                              a_dup_licensetypename,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_dup_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbykeywords(   a_dup_licenseenames
                                                          || '%');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_dup_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_dup_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_dup_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ExpirationDate', a_expirationdate, a_expirationdateupper);
        extension.pkg_cxproceduralsearch.performsearch(t_secondaryunfilteredobjects, 'and', 'none');

        --Filter out the Secondary LTs that are in the wrong status if statsu was given
        IF a_status IS NOT NULL THEN
            -- Find all LT categories that match the search criteria
            extension.pkg_cxproceduralsearch.initializesearch('o_LicenseTypeCategory');
            extension.pkg_cxproceduralsearch.searchbyindex('LicenseTypeCode',
                                                           a_dup_licensetypecode,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('LicenseTypeName',
                                                           a_dup_licensetypename,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.performsearch(t_secondarycategoryobjects, 'and', 'none');

            IF t_secondarycategoryobjects.COUNT = 0
           AND a_dup_licensetypecode IS NULL
           AND a_dup_licensetypename IS NULL THEN
                -- Find all License Type jobs with any secondaries in the selected status
                FOR c IN (SELECT lt.objectid ltjobid
                            FROM TABLE(CAST(t_secondaryunfilteredobjects AS api.udt_objectlist)) lt
                                 JOIN query.r_licensetypeltcatsecondary ltsec
                                 ON ltsec.licensetypejobid = lt.objectid
                           /*The commented WHERE clause caused full scan ObjectColumnData. Don Reid suggested using the ColumnQuery.Value instead.
                                             Changed by Andy Patterson (CXUSA) 10/27/2015
                                             The reason why this works better is because the old code assumed that an INDEX RANGE SCAN would perform well on ObjectColumnData.
                                             The code was getting everything where the WHERE clause matched and then matching against everything else.
                                             By using the function in the WHERE clause Oracle doesn't know how to access it so it will go aginst the table in memory first, then filter by the Status column.
                                             The Explain plan for the old code does a range scan on ObjectColumnData. The new code does not.*/
                           --where ltsec.Status = upper(a_Status)
                           WHERE api.pkg_columnquery.VALUE(ltsec.relationshipid, 'Status') = UPPER(a_status))
                LOOP
                    a_objects.EXTEND(1);  -- Use a_Objects as a temporary holding place
                    a_objects(a_objects.COUNT)   := api.udt_object(c.ltjobid);
                END LOOP;
            ELSE
                -- Find all License Type jobs with matching secondaries in the selected status
                FOR c IN (SELECT lt.objectid ltjobid
                            FROM TABLE(CAST(t_secondaryunfilteredobjects AS api.udt_objectlist)) lt
                                 JOIN query.r_licensetypeltcatsecondary ltsec
                                 ON ltsec.licensetypejobid = lt.objectid
                                 JOIN TABLE(CAST(t_secondarycategoryobjects AS api.udt_objectlist)) cat
                                 ON cat.objectid = ltsec.licensetypecategoryobjectid
                           --See Comments above
                           --where ltsec.Status = upper(a_Status)
                           WHERE api.pkg_columnquery.VALUE(ltsec.relationshipid, 'Status') = UPPER(a_status))
                LOOP
                    a_objects.EXTEND(1);  -- Use a_Objects as a temporary holding place
                    a_objects(a_objects.COUNT)   := api.udt_object(c.ltjobid);
                END LOOP;
            END IF;

            t_secondaryunfilteredobjects   := a_objects;
            a_objects.delete;  -- Delete a_Objects for processing later
        END IF;

        --Join the two searches together
        extension.pkg_collectionutils.append(t_unfilteredobjects, t_secondaryunfilteredobjects);

        --Filter out the LTs in the Pending Status if searching by an expiration date
        IF a_expirationdate IS NOT NULL
        OR a_expirationdateupper IS NOT NULL THEN
            FOR i IN 1 .. t_unfilteredobjects.COUNT
            LOOP
                t_filterstatus   := api.pkg_columnquery.VALUE(t_unfilteredobjects(i).objectid, 'StatusName');

                IF t_filterstatus != 'PEND' THEN
                    a_objects.EXTEND(1);
                    a_objects(a_objects.COUNT)   := t_unfilteredobjects(i);
                END IF;
            END LOOP;
        END IF;

        t_searchperformed              :=
            a_dup_licensetypecode IS NOT NULL
         OR a_dup_licensetypename IS NOT NULL
         OR a_dup_licenseexternalfilenum IS NOT NULL
         OR a_dup_licenseenames IS NOT NULL
         OR a_dup_licenseaddressline1 IS NOT NULL
         OR a_dup_licenseuscity IS NOT NULL
         OR a_dup_licensezipcode IS NOT NULL
         OR a_createddate IS NOT NULL
         OR a_createddateupper IS NOT NULL
         OR a_expirationdate IS NOT NULL
         OR a_expirationdateupper IS NOT NULL
         OR a_status IS NOT NULL;

        -- Filter By DBA Names if DBA was entered
        IF a_dup_licensedbas IS NOT NULL THEN
            t_keywordobjectlist   := api.udt_objectlist();

            -- Get all objects with this DBA as a keyword and convert it to an ObjectList for use in select
            extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                 api.pkg_simplesearch.objectsbykeywords('o_DBANames',
                                                                                           a_dup_licensedbas
                                                                                        || '%'));

            -- Find all License Types with a License that has this DBA Name
            SELECT llt.licensetypejobid
              BULK COLLECT INTO t_filteredobjectidlist
              FROM TABLE(t_keywordobjectlist) source
                   JOIN query.r_licensedbanames lidba
                   ON lidba.dbanamesobjectid = source.objectid
                   JOIN query.r_licenselicensetype llt
                   ON llt.licensejobid = lidba.licensejobid;

            -- Put results into the main list of found objects
            IF t_searchperformed THEN
                extension.pkg_collectionutils.join(t_unfilteredobjects, t_filteredobjectidlist);
            ELSE
                extension.pkg_collectionutils.append(t_unfilteredobjects, t_filteredobjectidlist);
            END IF;
        END IF;

        --a_Objects has not been populated becuase
        IF a_objects.COUNT = 0 THEN
            t_count   := t_unfilteredobjects.COUNT;

            IF t_count <= t_findlicensetype
            OR a_override = 'Y' THEN
                a_objects   := t_unfilteredobjects;
            ELSE
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_findlicensetype
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        ELSE
            t_count   := a_objects.COUNT;

            IF t_count <= t_findlicensetype
            OR a_override = 'Y' THEN
                NULL;
            ELSE
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_findlicensetype
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        END IF;

        t_unfilteredobjects.delete;
    END findlicensetype;

    PROCEDURE findmanagepriorityapplication(a_managepriorityappsnumber   VARCHAR2,
                                            a_createddate                DATE,
                                            a_createddateupper           DATE,
                                            a_status                     VARCHAR2,
                                            a_applicationnumber          VARCHAR2,
                                            a_applicantnames             VARCHAR2,
                                            a_officecodeandname          VARCHAR2,
                                            a_countycodeandname          VARCHAR2,
                                            a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects    api.udt_objectlist;
        t_status               VARCHAR2(100);
        t_findmanagepriority   NUMBER(9, 0);
        t_count                NUMBER(9, 0);
    BEGIN
        a_objects              := api.udt_objectlist();
        t_unfilteredobjects    := api.udt_objectlist();
        t_findmanagepriority   := api.pkg_constantquery.VALUE('FINDMANAGEPRIORITYAPPLICATION');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('j_ManagePriorityApplications');
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     a_managepriorityappsnumber,
                                                     t_status,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PriorityApplication',
                                                              'dup_LicenseNumber',
                                                              a_applicationnumber,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PriorityApplication',
                                                              'dup_ApplicantNames',
                                                              a_applicantnames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PDOffice',
                                                              'dup_Office',
                                                              a_officecodeandname,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CACounty',
                                                              'dup_County',
                                                              a_countycodeandname,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        t_count                := t_unfilteredobjects.COUNT;

        IF t_count <= t_findmanagepriority THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findmanagepriority
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
    END findmanagepriorityapplication;

    PROCEDURE findmanualfee(a_licensetypecode            VARCHAR2,
                            a_effectivedate              DATE,
                            a_effectivedateupper         DATE,
                            a_description                VARCHAR2,
                            a_searchforhistoricalrecords VARCHAR2,
                            a_excludeobjectids           VARCHAR2,
                            a_processid                  udt_id,
                            a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_excludeobjectlist            api.udt_objectlist;
        t_excludeobjectids             VARCHAR2(1000)
                                           :=    a_excludeobjectids
                                              || ',';
        t_start                        NUMBER := 1;

        TYPE array1 IS VARRAY(100) OF VARCHAR2(2);

        TYPE array2 IS VARRAY(100) OF VARCHAR2(60);

        p_temp                         array1;
        s_temp                         array1;
        pa_temp                        array1;
        gr_temp                        array2;
        pr_temp                        array2;
        nm_temp                        array2;
        sp_temp                        array2;
        t_includeactivityfeecode       array2;
        t_searchforhistoricalrecords   CHAR(1);
        t_objectlist                   api.udt_objectlist := api.udt_objectlist();
    BEGIN
        t_excludeobjectlist                                        := api.udt_objectlist();

        WHILE INSTR(t_excludeobjectids, ',', t_start) > 0
          AND a_excludeobjectids IS NOT NULL
        LOOP
            t_excludeobjectlist.EXTEND(1);
            t_excludeobjectlist(t_excludeobjectlist.COUNT)   :=
                api.udt_object(
                    SUBSTR(t_excludeobjectids, t_start, INSTR(t_excludeobjectids, ',', t_start) - t_start));
            t_start   := INSTR(t_excludeobjectids, ',', t_start) + 2;
        END LOOP;

        a_objects                                                  := api.udt_objectlist();

        IF a_licensetypecode IS NULL
       AND a_effectivedate IS NULL
       AND a_effectivedateupper IS NULL
       AND a_description IS NULL THEN
            api.pkg_errors.raiseerror(-20000,
                                      'No information was found matching your selection criteria. Please try again.');
        ELSE
            NULL;
        END IF;

        --Set the Fee Codes to be included whether or not their Gallonage Range, Population Range,
        --and Number of Months Licensed match. You may add more exceptions to this list.
        t_includeactivityfeecode                                   := array2();
        t_includeactivityfeecode.EXTEND(1);
        t_includeactivityfeecode(t_includeactivityfeecode.COUNT)   := 'RPL';
        t_includeactivityfeecode.EXTEND(1);
        t_includeactivityfeecode(t_includeactivityfeecode.COUNT)   := 'IPT';
        t_includeactivityfeecode.EXTEND(1);
        t_includeactivityfeecode(t_includeactivityfeecode.COUNT)   := 'MOD';
        t_includeactivityfeecode.EXTEND(1);
        t_includeactivityfeecode(t_includeactivityfeecode.COUNT)   := 'MGR';  -- Sheik WO# 17279 fixing for type 49 to include MGR in t_objectlist

        --Based on the input parameters, choose whether or not to search for Historical (Inactive) records
        t_searchforhistoricalrecords                               :=
            CASE
                WHEN a_searchforhistoricalrecords = 'Y' THEN
                    'Y'
                WHEN a_effectivedate IS NOT NULL
                  OR a_effectivedateupper IS NOT NULL THEN
                    'Y'
                ELSE
                    'N'
            END;

        -- Make sure nothing exists in the objectlist
        t_objectlist.delete;

        --Select PrimaryLTCodes into a bulk collect
        SELECT primarylt,
               gallonagerange,
               populationrange,
               numberofmonthslicensed,
               prioritydraw
          BULK COLLECT INTO p_temp,
               gr_temp,
               pr_temp,
               nm_temp,
               pa_temp
          FROM (SELECT api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode')
                           primarylt,
                       DECODE(ltc.gallonageapplies, 'Y', api.pkg_columnquery.VALUE(p.jobid, 'GallonageRange'))
                           gallonagerange,
                       CASE
                           WHEN a_description = 'MGR' THEN
                               NULL
                           ELSE
                               DECODE(ltc.populationapplies,
                                      'Y', api.pkg_columnquery.VALUE(p.jobid, 'PremisesPopulationRange'))
                       END
                           populationrange,
                       DECODE(
                           DECODE(ltc.seasonalmonthsapply,
                                  'Y', api.pkg_columnquery.VALUE(p.jobid, 'NumberOfMonthsLicensedFeeCode')),
                           '0-3MOS', '3 MONTHS',
                           '3-6MOS', '6 MONTHS',
                           '6-9MOS', '9 MONTHS')
                           numberofmonthslicensed,
                       ltc.prioritydrawlicensetype
                           prioritydraw
                  FROM api.processes p
                       JOIN api.relationships r
                       ON r.fromobjectid = p.jobid
                      AND r.endpointid IN
                              (api.pkg_configquery.endpointidforname('j_OneDayLicense', 'LicenseTypeCategory'),
                               api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatPrimary'))
                       JOIN query.o_licensetypecategory ltc
                       ON ltc.objectid = r.toobjectid
                 WHERE p.processid = a_processid
                UNION ALL
                SELECT api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode')
                           primarylt,
                       DECODE(
                           ltc.gallonageapplies,
                           'Y', NVL(api.pkg_columnquery.VALUE(r.toobjectid, 'GallonageRange'),
                                    api.pkg_columnquery.VALUE(p.jobid, 'GallonageRange')))
                           gallonagerange,
                       CASE
                           WHEN a_description = 'MGR' THEN
                               NULL
                           ELSE
                               DECODE(ltc.populationapplies,
                                      'Y', api.pkg_columnquery.VALUE(p.jobid, 'PremisesPopulationRange'))
                       END
                           populationrange,
                       DECODE(
                           DECODE(ltc.seasonalmonthsapply,
                                  'Y', api.pkg_columnquery.VALUE(r.toobjectid, 'NumberOfMonthsLicensedFeeCode')),
                           '0-3MOS', '3 MONTHS',
                           '3-6MOS', '6 MONTHS',
                           '6-9MOS', '9 MONTHS')
                           numberofmonthslicensed,
                       ltc.prioritydrawlicensetype
                           prioritydraw
                  FROM api.processes p
                       JOIN api.relationships r
                       ON r.fromobjectid = p.jobid
                      AND r.endpointid IN
                              (api.pkg_configquery.endpointidforname('j_Application', 'PrimaryLicenseType'),
                               api.pkg_configquery.endpointidforname('j_License', 'LicenseType'))
                       JOIN api.relationships r2
                       ON r2.fromobjectid = r.toobjectid
                      AND r2.endpointid IN
                              (api.pkg_configquery.endpointidforname('o_PrimaryLicenseType', 'LicTypeCatPrimary'),
                               api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatPrimary'))
                       JOIN query.o_licensetypecategory ltc
                       ON ltc.objectid = r2.toobjectid
                 WHERE p.processid = a_processid);

        --select the SecondaryLTCodes into a bulk collect
        SELECT secondarylt, populationrange
          BULK COLLECT INTO s_temp, sp_temp
          FROM (SELECT ltc.licensetypecode
                           secondarylt,
                       CASE
                           WHEN a_description = 'MGR' THEN
                               NULL
                           ELSE
                               DECODE(ltc.populationapplies,
                                      'Y', api.pkg_columnquery.VALUE(p.jobid, 'PremisesPopulationRange'))
                       END
                           populationrange
                  FROM api.processes p
                       JOIN api.relationships r
                       ON r.fromobjectid = p.jobid
                      AND r.endpointid =
                          api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatSecondary')
                       JOIN query.o_licensetypecategory ltc
                       ON ltc.objectid = r.toobjectid
                 WHERE p.processid = a_processid
                   AND ltc.licensetypecode IS NOT NULL
                UNION ALL
                SELECT ltc.licensetypecode
                           secondarylt,
                       CASE
                           WHEN a_description = 'MGR' THEN
                               NULL
                           ELSE
                               DECODE(ltc.populationapplies,
                                      'Y', api.pkg_columnquery.VALUE(sr.fromobjectid, 'PremisesPopulationRange'))
                       END
                           populationrange
                  FROM api.processes p
                       JOIN api.relationships r
                       ON r.fromobjectid = p.jobid
                      AND r.endpointid IN
                              (api.pkg_configquery.endpointidforname('j_Application', 'PrimaryLicenseType'),
                               api.pkg_configquery.endpointidforname('j_License', 'LicenseType'))
                       JOIN api.relationships sr
                       ON sr.fromobjectid = r.toobjectid
                      AND sr.endpointid IN
                              (api.pkg_configquery.endpointidforname('o_PrimaryLicenseType', 'LicTypeCatSecondary'),
                               api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatSecondary'))
                       JOIN query.o_licensetypecategory ltc
                       ON ltc.objectid = sr.toobjectid
                 WHERE p.processid = a_processid
                   AND ltc.licensetypecode IS NOT NULL);


        --Search for Primary Values
        FOR primary IN 1 .. p_temp.COUNT
        LOOP
            extension.pkg_cxproceduralsearch.initializesearch('o_FeeSchedule');
            extension.pkg_cxproceduralsearch.searchbyindex('LicenseTypeCode',
                                                           p_temp(primary),
                                                           NULL,
                                                           TRUE);

            -- For searches for POIC fees, do not search based on the FeeCode data.
            IF a_description <> 'POIC'
           AND pa_temp(primary) != 'Y'
            OR (pa_temp(primary) = 'Y'
            AND a_description != 'ORI') THEN
                extension.pkg_cxproceduralsearch.searchbyindex('GallonageRange',
                                                               gr_temp(primary),
                                                               NULL,
                                                               FALSE);
                extension.pkg_cxproceduralsearch.searchbyindex('PopulationRange',
                                                               pr_temp(primary),
                                                               NULL,
                                                               FALSE);
                extension.pkg_cxproceduralsearch.searchbyindex('NumberOfMonthsLicensed',
                                                               nm_temp(primary),
                                                               NULL,
                                                               FALSE);
            END IF;

            extension.pkg_cxproceduralsearch.performsearch(t_objectlist, 'and', 'or');

            --In addition, get all the Fee Schedules in the Fee Code Activity Exception list.
            FOR i IN 1 .. t_includeactivityfeecode.COUNT
            LOOP
                extension.pkg_cxproceduralsearch.initializesearch('o_FeeSchedule');
                extension.pkg_cxproceduralsearch.searchbyindex('LicenseTypeCode',
                                                               p_temp(primary),
                                                               NULL,
                                                               TRUE);
                extension.pkg_cxproceduralsearch.searchbyindex('FeeActivity',
                                                               t_includeactivityfeecode(i),
                                                               NULL,
                                                               FALSE);
                extension.pkg_cxproceduralsearch.performsearch(t_objectlist, 'and', 'or');
            END LOOP;
        END LOOP;

        --Search for Secondary Values
        FOR secondary IN 1 .. s_temp.COUNT
        LOOP
            extension.pkg_cxproceduralsearch.initializesearch('o_FeeSchedule');
            extension.pkg_cxproceduralsearch.searchbyindex('LicenseTypeCode',
                                                           s_temp(secondary),
                                                           NULL,
                                                           TRUE);

            -- For searches for POIC fees, do not search based on the FeeCode data.
            IF a_description <> 'POIC' THEN
                extension.pkg_cxproceduralsearch.searchbyindex('PopulationRange',
                                                               sp_temp(secondary),
                                                               NULL,
                                                               FALSE);
            END IF;

            extension.pkg_cxproceduralsearch.performsearch(t_objectlist, 'and', 'or');

            --In addition, get all the Fee Schedules in the Fee Code Activity Exception list.
            FOR i IN 1 .. t_includeactivityfeecode.COUNT
            LOOP
                extension.pkg_cxproceduralsearch.initializesearch('o_FeeSchedule');
                extension.pkg_cxproceduralsearch.searchbyindex('LicenseTypeCode',
                                                               s_temp(secondary),
                                                               NULL,
                                                               TRUE);
                extension.pkg_cxproceduralsearch.searchbyindex('FeeActivity',
                                                               t_includeactivityfeecode(i),
                                                               NULL,
                                                               FALSE);
                extension.pkg_cxproceduralsearch.performsearch(t_objectlist, 'and', 'or');
            END LOOP;
        END LOOP;


        IF t_searchforhistoricalrecords = 'Y' THEN
            --Pull in all records for criteria entered.
            FOR c
                IN (SELECT t.objectid
                      FROM feeschedule_t t
                     WHERE ((t.licensetypecode LIKE
                                    a_licensetypecode
                                 || '%')
                         OR a_licensetypecode IS NULL)
                       AND ((TRUNC(t.effectivedate) >= a_effectivedate)
                         OR a_effectivedate IS NULL)
                       AND ((TRUNC(t.effectivedate) <= a_effectivedateupper)
                         OR a_effectivedateupper IS NULL)
                       AND ((LOWER(t.description) LIKE
                                    LOWER(a_description)
                                 || '%')
                         OR a_description IS NULL)
                       AND t.objectid NOT IN
                               (SELECT objectid FROM TABLE(CAST(t_excludeobjectlist AS api.udt_objectlist)))
                       AND (t.objectid IN (SELECT objectid FROM TABLE(CAST(t_objectlist AS api.udt_objectlist)))
                         OR t.licensetypecode IS NULL))
            LOOP
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(c.objectid);
            END LOOP;
        ELSE  --Only get records with maximum effective date for other criteria entered.
            FOR c
                IN (SELECT t.objectid
                      FROM feeschedule_t t
                     WHERE ((t.licensetypecode LIKE
                                    a_licensetypecode
                                 || '%')
                         OR a_licensetypecode IS NULL)
                       AND ((LOWER(t.description) LIKE
                                    LOWER(a_description)
                                 || '%')
                         OR a_description IS NULL)
                       AND t.effectivedate = (SELECT MAX(q.effectivedate)
                                                FROM feeschedule_t q
                                               WHERE ((q.licensetypecode = t.licensetypecode)
                                                   OR (q.licensetypecode IS NULL
                                                   AND t.licensetypecode IS NULL))
                                                 AND ((LOWER(q.description) = LOWER(t.description)))
                                                 AND (q.populationrange = t.populationrange
                                                   OR (q.populationrange IS NULL
                                                   AND t.populationrange IS NULL))
                                                 AND (q.gallonagerange = t.gallonagerange
                                                   OR (q.gallonagerange IS NULL
                                                   AND t.gallonagerange IS NULL))
                                                 AND (q.numberofmonthslicensed = t.numberofmonthslicensed
                                                   OR (q.numberofmonthslicensed IS NULL
                                                   AND t.numberofmonthslicensed IS NULL))
                                                 AND (q.otherfeecode = t.otherfeecode
                                                   OR (q.otherfeecode IS NULL
                                                   AND t.otherfeecode IS NULL))
                                                 AND TRUNC(q.effectivedate) <= TRUNC(SYSDATE))
                       AND t.objectid NOT IN
                               (SELECT objectid FROM TABLE(CAST(t_excludeobjectlist AS api.udt_objectlist)))
                       AND (t.objectid IN (SELECT objectid FROM TABLE(CAST(t_objectlist AS api.udt_objectlist)))
                         OR t.licensetypecode IS NULL)
                       AND t.inactive = 'N')
            LOOP
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(c.objectid);
            END LOOP;
        END IF;
    END findmanualfee;

    ---------------------------------------------------------------------------------------------------
    --  FindMasterLicenseType() -- PUBLIC
    --  Used by Outrider on the Application when establishing a Branch License Type
    --  Searches for a License with a Master License Type to "sponsor" the Branch.
    ---------------------------------------------------------------------------------------------------
    PROCEDURE findmasterlicensetype(a_licenseexternalfilenum     VARCHAR2,
                                    a_licenseenames              VARCHAR2,
                                    a_licenseaddressline1        VARCHAR2,
                                    a_licenseuscity              VARCHAR2,
                                    a_licensezipcode             VARCHAR2,
                                    a_licensedbas                VARCHAR2,
                                    a_fromprimarylicensetype     NUMBER,
                                    a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        SUBTYPE udt_licensetypecodes IS pkg_licensetype.udt_licensetypecodes;

        t_licensetypecodes       udt_licensetypecodes;
        t_unfilteredobjects      api.udt_objectlist;
        t_validmasterltobjects   api.udt_objectlist;
    BEGIN
        a_objects                := api.udt_objectlist();
        t_unfilteredobjects      := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonLicensee',
                                                              'dup_FormattedPersonNameSearch',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        --    extension.pkg_cxproceduralsearch.SearchByIndex('MasterLicenseType', 'Y', null, false);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseType',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchPy',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12PersonLicensee',
                                                              'dup_FormattedPersonNameSearch',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        --    extension.pkg_cxproceduralsearch.SearchByIndex('MasterLicenseType', 'Y', null, false);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseType',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchPy',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyLicensee',
                                                              'CompanyName',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        --    extension.pkg_cxproceduralsearch.SearchByIndex('MasterLicenseType', 'Y', null, false);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseType',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchPy',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('License',
                                                              'ExternalFileNum',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12CompanyLicensee',
                                                              'CompanyName',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        --    extension.pkg_cxproceduralsearch.SearchByIndex('MasterLicenseType', 'Y', null, false);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseType',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchPy',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        t_licensetypecodes       := pkg_licensetype.validmasterlicensetypesonplt(a_fromprimarylicensetype);

        t_validmasterltobjects   := api.udt_objectlist();

        FOR i IN 1 .. t_licensetypecodes.COUNT
        LOOP
            extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
            extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseTypeCode',
                                                           t_licensetypecodes(i),
                                                           t_licensetypecodes(i),
                                                           FALSE);
            extension.pkg_cxproceduralsearch.performsearch(t_validmasterltobjects, 'and', 'or');
        END LOOP;

        IF t_validmasterltobjects.COUNT > 0 THEN
            SELECT api.udt_object(uo.objectid)
              BULK COLLECT INTO a_objects
              FROM TABLE(CAST(t_unfilteredobjects AS api.udt_objectlist)) uo
                   JOIN TABLE(CAST(t_validmasterltobjects AS api.udt_objectlist)) mlt
                   ON mlt.objectid = uo.objectid
             WHERE uo.objectid <> a_fromprimarylicensetype;
        ELSE
            a_objects   := t_unfilteredobjects;
        END IF;

        t_unfilteredobjects.delete;
        t_validmasterltobjects.delete;
    END findmasterlicensetype;

    PROCEDURE findmasterprimarylicensetype(a_licenseexternalfilenum     VARCHAR2,
                                           a_licenseenames              VARCHAR2,
                                           a_licenseaddressline1        VARCHAR2,
                                           a_licenseuscity              VARCHAR2,
                                           a_licensezipcode             VARCHAR2,
                                           a_licensedbas                VARCHAR2,
                                           a_fromprimarylicensetype     NUMBER,
                                           a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        SUBTYPE udt_licensetypecodes IS pkg_licensetype.udt_licensetypecodes;

        t_licensetypecodes       udt_licensetypecodes;
        t_unfilteredobjects      api.udt_objectlist;
        t_validmasterltobjects   api.udt_objectlist;
    BEGIN
        a_objects                := api.udt_objectlist();
        t_unfilteredobjects      := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonLicensee',
                                                              'dup_FormattedPersonNameSearch',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseTypeExp',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchS',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsNotIssuedVoided',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12PersonLicensee',
                                                              'dup_FormattedPersonNameSearch',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseTypeExp',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchS',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsNotIssuedVoided',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyApplicant',
                                                              'CompanyName',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseTypeExp',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchS',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsNotIssuedVoided',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Application',
                                                              'dup_LicenseNumber',
                                                              a_licenseexternalfilenum,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12CompanyApplicant',
                                                              'CompanyName',
                                                              a_licenseenames,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'AddressLine1',
                                                              a_licenseaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USACity',
                                                              a_licenseuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'ZipCode',
                                                              a_licensezipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                              'DBA',
                                                              a_licensedbas,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('MasterLicenseTypeExp',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsBranchS',
                                                       'N',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('IsNotIssuedVoided',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        t_licensetypecodes       := pkg_licensetype.validmasterlicensetypesonplt(a_fromprimarylicensetype);

        t_validmasterltobjects   := api.udt_objectlist();

        FOR i IN 1 .. t_licensetypecodes.COUNT
        LOOP
            extension.pkg_cxproceduralsearch.initializesearch('o_PrimaryLicenseType');
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('LicTypeCatPrimary',
                                                                  'LicenseTypeCode',
                                                                  t_licensetypecodes(i),
                                                                  t_licensetypecodes(i),
                                                                  FALSE);
            extension.pkg_cxproceduralsearch.performsearch(t_validmasterltobjects, 'and', 'or');
        END LOOP;

        IF t_validmasterltobjects.COUNT > 0 THEN
            SELECT api.udt_object(uo.objectid)
              BULK COLLECT INTO a_objects
              FROM TABLE(CAST(t_unfilteredobjects AS api.udt_objectlist)) uo
                   JOIN TABLE(CAST(t_validmasterltobjects AS api.udt_objectlist)) mlt
                   ON mlt.objectid = uo.objectid
             WHERE uo.objectid <> a_fromprimarylicensetype;
        ELSE
            a_objects   := t_unfilteredobjects;
        END IF;

        t_unfilteredobjects.delete;
        t_validmasterltobjects.delete;
    END findmasterprimarylicensetype;

    PROCEDURE findmiscellaneousfee(a_externalfilenum            VARCHAR2,
                                   a_createddate                DATE,
                                   a_createddateupper           DATE,
                                   a_status                     VARCHAR2,
                                   a_paidfor                    VARCHAR2,
                                   a_amount                     NUMBER,
                                   a_receiptingoffice           VARCHAR2,
                                   a_receiptnumber              VARCHAR2,
                                   a_feedescription             VARCHAR2,
                                   a_receiptingcompletedby      VARCHAR2,
                                   a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects      api.udt_objectlist;
        t_status                 VARCHAR2(6);
        t_findmiscellaneousfee   NUMBER(9, 0);
        t_count                  NUMBER(9, 0);
    BEGIN
        a_objects                := api.udt_objectlist();
        t_unfilteredobjects      := api.udt_objectlist();
        t_findmiscellaneousfee   := api.pkg_constantquery.VALUE('FINDMISCELLANEOUSFEE');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('j_MiscellaneousFee');
        extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                       a_externalfilenum,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     t_status,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyindex('PaidFor',
                                                       a_paidfor,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Payment',
                                                              'PaymentAmountStored',
                                                              a_amount,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('office',
                                                              'dup_Office',
                                                              a_receiptingoffice,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('payment',
                                                              'dup_ReceiptNumber',
                                                              a_receiptnumber,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Fee',
                                                              'dup_DescriptionForDisplay',
                                                              a_feedescription,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF a_receiptingcompletedby IS NOT NULL
       AND a_externalfilenum IS NULL
       AND a_createddate IS NULL
       AND a_paidfor IS NULL
       AND a_amount IS NULL
       AND a_receiptingoffice IS NULL
       AND a_receiptnumber IS NULL THEN
            FOR q IN (SELECT rp.completedby, j.jobid
                        FROM api.jobs j
                             JOIN query.p_receiptpayments rp
                             ON rp.jobid = j.jobid)
            LOOP
                IF UPPER(q.completedby) LIKE
                       UPPER(   a_receiptingcompletedby
                             || '%') THEN
                    a_objects.EXTEND(1);
                    a_objects(a_objects.COUNT)   := api.udt_object(q.jobid);
                END IF;
            END LOOP;
        ELSIF a_receiptingcompletedby IS NOT NULL THEN
            -- and a_ExternalFileNum is not null or a_CreatedDate is not null or a_PaidFor is not null or a_Amount is not null or a_ReceiptingOffice is not null or a_ReceiptNumber is not null then
            FOR q IN (SELECT rp.completedby, j.jobid
                        FROM api.jobs j
                             JOIN query.p_receiptpayments rp
                             ON rp.jobid = j.jobid
                             JOIN TABLE(CAST(t_unfilteredobjects AS api.udt_objectlist)) uo
                             ON uo.objectid = j.jobid)
            LOOP
                IF UPPER(q.completedby) LIKE
                       UPPER(   a_receiptingcompletedby
                             || '%') THEN
                    a_objects.EXTEND(1);
                    a_objects(a_objects.COUNT)   := api.udt_object(q.jobid);
                END IF;
            END LOOP;
        ELSE
            a_objects   := t_unfilteredobjects;
        END IF;

        IF a_objects.COUNT > t_findmiscellaneousfee THEN
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findmiscellaneousfee
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
    END findmiscellaneousfee;

    /**************************************************************************************************
        * FindOneDayLicense() -- PUBLIC
        *   Search for One Day License Jobs
        **************************************************************************************************/
    PROCEDURE findonedaylicense(a_externalfilenum            VARCHAR2,
                                a_organizationname           VARCHAR2,
                                a_eventlocaddressline1       VARCHAR2,
                                a_eventlocuscity             VARCHAR2,
                                a_eventloczipcode            VARCHAR2,
                                a_eventyear                  NUMBER,
                                a_representativename         VARCHAR2,
                                a_createddate                DATE,
                                a_createddateupper           DATE,
                                a_status                     VARCHAR2,
                                a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects      api.udt_objectlist;
        t_filteredobjectidlist   udt_idlist;
        t_keywordobjectlist      api.udt_objectlist;
        t_status                 VARCHAR2(6);
        t_findonedaylicense      NUMBER(9, 0);
        t_count                  NUMBER(9, 0);
        t_searchperformed        BOOLEAN;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_findonedaylicense   := api.pkg_constantquery.VALUE('FINDONEDAYLICENSE');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('j_OneDayLicense');

        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     t_status,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                       a_externalfilenum,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('EventLocation',
                                                              'AddressLine1',
                                                              a_eventlocaddressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('EventLocation',
                                                              'USACity',
                                                              a_eventlocuscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('EventLocation',
                                                              'ZipCode',
                                                              a_eventloczipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('dup_EventYear',
                                                       a_eventyear,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbykeywords(   a_representativename
                                                          || '%');

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        t_searchperformed     :=
            a_externalfilenum IS NOT NULL
         OR a_eventlocaddressline1 IS NOT NULL
         OR a_eventlocuscity IS NOT NULL
         OR a_eventloczipcode IS NOT NULL
         OR a_eventyear IS NOT NULL
         OR a_representativename IS NOT NULL
         OR a_createddate IS NOT NULL
         OR a_createddateupper IS NOT NULL
         OR a_status IS NOT NULL;

        -- Search for Companies if Organization Name was entered
        IF a_organizationname IS NOT NULL THEN
            t_keywordobjectlist   := api.udt_objectlist();

            -- Get all objects with this organization as a keyword and convert it to an ObjectList for use in select
            extension.pkg_collectionutils.append(t_keywordobjectlist,
                                                 api.pkg_simplesearch.objectsbykeywords('o_Company',
                                                                                           a_organizationname
                                                                                        || '%'));

            -- Find all Applications with this Company or Person as the License
            SELECT codl.onedaylicensejobid
              BULK COLLECT INTO t_filteredobjectidlist
              FROM TABLE(t_keywordobjectlist) source
                   JOIN query.r_companyonedaylicense codl
                   ON codl.companyobjectid = source.objectid;

            -- Put results into the main list of found objects
            IF t_searchperformed THEN
                extension.pkg_collectionutils.join(t_unfilteredobjects, t_filteredobjectidlist);
            ELSE
                extension.pkg_collectionutils.append(t_unfilteredobjects, t_filteredobjectidlist);
            END IF;
        END IF;

        t_count               := t_unfilteredobjects.COUNT;

        IF t_count <= t_findonedaylicense THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findonedaylicense
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
    END findonedaylicense;

    PROCEDURE findp12(a_companyname                VARCHAR2,
                      a_firstname                  VARCHAR2,
                      a_lastname                   VARCHAR2,
                      a_addressline1               VARCHAR2,
                      a_uscity                     VARCHAR2,
                      a_usstate                    VARCHAR2,
                      a_zipcode                    NUMBER,
                      a_licensenumber              VARCHAR2,
                      a_p12status                  CHAR,
                      a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('o_LegalEntity');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Company',
                                                              'CompanyName',
                                                              a_companyname,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Person',
                                                              'FirstName',
                                                              a_firstname,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Person',
                                                              'LastName',
                                                              a_lastname,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonAddress',
                                                              'AddressLine1',
                                                              a_addressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonAddress',
                                                              'USACity',
                                                              a_uscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonAddress',
                                                              'USAState',
                                                              a_usstate,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonAddress',
                                                              'ZipCode',
                                                              a_zipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                       a_licensenumber,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('P12Status',
                                                       a_p12status,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('o_LegalEntity');
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Company',
                                                              'CompanyName',
                                                              a_companyname,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Person',
                                                              'FirstName',
                                                              a_firstname,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Person',
                                                              'LastName',
                                                              a_lastname,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyAddress',
                                                              'AddressLine1',
                                                              a_addressline1,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyAddress',
                                                              'USACity',
                                                              a_uscity,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyAddress',
                                                              'USAState',
                                                              a_usstate,
                                                              NULL,
                                                              FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyAddress',
                                                              'ZipCode',
                                                              a_zipcode,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                       a_licensenumber,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('P12Status',
                                                       a_p12status,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        a_objects             := t_unfilteredobjects;
        t_unfilteredobjects.delete;
    END findp12;


    PROCEDURE findpayment(a_jobid            NUMBER,
                          a_jobnumber        VARCHAR2,
                          a_excludeobjectids VARCHAR2,
                          a_objectlist   OUT api.udt_objectlist)
    IS
        t_excludeobjectlist    api.udt_objectlist;
        t_excludeobjectids     VARCHAR2(1000)
                                   :=    a_excludeobjectids
                                      || ',';
        t_start                NUMBER := 1;
        t_paymentobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_Payment');
    BEGIN
        t_excludeobjectlist   := api.udt_objectlist();

        WHILE INSTR(t_excludeobjectids, ',', t_start) > 0
          AND a_excludeobjectids IS NOT NULL
        LOOP
            t_excludeobjectlist.EXTEND(1);
            t_excludeobjectlist(t_excludeobjectlist.COUNT)   :=
                api.udt_object(
                    SUBSTR(t_excludeobjectids, t_start, INSTR(t_excludeobjectids, ',', t_start) - t_start));
            t_start   := INSTR(t_excludeobjectids, ',', t_start) + 2;
        END LOOP;

        a_objectlist          := api.udt_objectlist();

        FOR c
            IN (SELECT DISTINCT e.objectid
                  FROM api.jobs j
                       JOIN api.fees f
                       ON f.jobid = j.jobid
                       JOIN api.feetransactions ft
                       ON ft.feeid = f.feeid
                       JOIN api.paymenttransactions pt
                       ON pt.transactionid = ft.transactionid
                       JOIN api.payments p
                       ON p.paymentid = pt.paymentid
                       JOIN api.registeredexternalobjects e
                       ON e.linkvalue = TO_CHAR(p.paymentid)
                      AND e.objectdefid = t_paymentobjectdefid
                 WHERE ((j.externalfilenum = a_jobnumber
                     AND a_jobnumber IS NOT NULL)
                     OR j.jobid = a_jobid)
                   AND e.objectid NOT IN
                           (SELECT objectid FROM TABLE(CAST(t_excludeobjectlist AS api.udt_objectlist)))
                   AND api.pkg_columnquery.VALUE(e.objectid, 'IsReceipted') = 'N'  --This is only N when the Receipt process is not complete, hence the second check.
                   AND api.pkg_columnquery.VALUE(e.objectid, 'ReceiptPaymentId') IS NULL
                   AND api.pkg_columnquery.VALUE(e.objectid, 'BatchPaymentId') IS NULL
                   AND api.pkg_columnquery.VALUE(e.objectid, 'IsRefund') != 'Y'
                   AND api.pkg_columnquery.VALUE(e.objectid, 'IsVoidedFlag') != 'Y')
        LOOP
            a_objectlist.EXTEND(1);
            a_objectlist(a_objectlist.COUNT)   := api.udt_object(c.objectid);
        END LOOP;
    END findpayment;

    PROCEDURE findpaymenttransactions(a_licensenumber    VARCHAR2,
                                      a_licensetypecode  VARCHAR2,
                                      a_objectlist   OUT api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_process               NUMBER;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        a_objectlist          := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        --Application
        extension.pkg_cxproceduralsearch.initializesearch('j_Application');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber', a_licensenumber, NULL);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');
        --License
        extension.pkg_cxproceduralsearch.initializesearch('j_License');
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     a_licensenumber,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');
        --License Type
        extension.pkg_cxproceduralsearch.initializesearch('j_LicenseType');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseExternalFileNum', a_licensenumber, NULL);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');
        --Accusation
        extension.pkg_cxproceduralsearch.initializesearch('j_Accusation');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber', a_licensenumber, NULL);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');
        --One Day License
        extension.pkg_cxproceduralsearch.initializesearch('j_OneDayLicense');
        extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum', a_licensenumber, NULL);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');
        --Misc Fee License Added by Pawan on 7/29/2014 for ticket 3348
        extension.pkg_cxproceduralsearch.initializesearch('j_MiscellaneousFee');
        extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum', a_licensenumber, NULL);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');


        FOR i IN 1 .. t_unfilteredobjects.COUNT
        LOOP
            --      dbms_output.put_line(t_UnfilteredObjects(i).ObjectId); --Testing Only

            --find matching Payment Transactions for the Application/License job
            FOR x IN (SELECT pt.objectid
                        FROM api.fees f
                             JOIN sitespecific.feeschedule_t fs
                             ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                             JOIN api.feetransactions ft
                             ON ft.feeid = f.feeid
                             --join api.paymenttransactions apt   --APatterson: PIP Task 8.5
                             --  on apt.TransactionId = ft.TransactionId
                             JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                             ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             JOIN query.o_paymenttransactions pt
                             ON pt.objectid = reo.objectid
                       WHERE f.jobid = t_unfilteredobjects(i).objectid
                         AND (fs.licensetypecode = a_licensetypecode
                           OR a_licensetypecode IS NULL)
                         AND pt.paymentamount > 0
                         AND pt.isdishonored <> 'Y'
                         AND pt.isvoidedflag <> 'Y'
                         AND pt.isrefunded <> 'Y'  --added KL 04_26_2010
                      --and api.pkg_columnquery.value(pto.objectid, 'PaymentStatus') is null --MM Issue1437
                      UNION
                      -- Getting records from  Misc Fee Added by Pawan on 8/2/2014 to resolve ticket 3348
                      SELECT pt.objectid
                        FROM api.fees f
                             JOIN query.o_miscfeeschedule fs
                             ON fs.objectid = sitespecific.pkg_fees.getmiscfeeschedulobjid(f.feeid)
                             -- join sitespecific.feeschedule_t fs on fs.objectid = sitespecific.pkg_fees.GetLicFeeSchedulObjId(f.FeeId)
                             JOIN api.feetransactions ft
                             ON ft.feeid = f.feeid
                             --join api.paymenttransactions apt    --APatterson: PIP Task 8.5
                             --  on apt.TransactionId = ft.TransactionId
                             JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                             ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             JOIN query.o_paymenttransactions pt
                             ON pt.objectid = reo.objectid
                       WHERE f.jobid = t_unfilteredobjects(i).objectid
                         --  and (fs.licensetypecode = a_LicenseTypeCode
                         --   or a_LicenseTypeCode is null)
                         AND pt.paymentamount > 0
                         AND pt.isdishonored <> 'Y'
                         AND pt.isvoidedflag <> 'Y'
                         AND pt.isrefunded <> 'Y'  --added KL 04_26_2010
                                                 --and api.pkg_columnquery.value(pto.objectid, 'PaymentStatus') is null --MM Issue1437
                                                 -- added union on 8/2/2014 by Pawan to resolve ticket 3348
                                                 )
            LOOP
                a_objectlist.EXTEND(1);
                a_objectlist(a_objectlist.COUNT)   := api.udt_object(x.objectid);
            END LOOP;
        END LOOP;
    END findpaymenttransactions;


    -- 07/24/2019 TJL  WO 17980 Added new search procedure to get payment transactions
    --                            that have not been earned.
    PROCEDURE findpaymenttransunearned(a_licensenumber IN    VARCHAR2,
                                       a_licensetypecode IN  VARCHAR2,
                                       a_objectlist      OUT api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;

        t_earned              BOOLEAN;
        t_transfered          BOOLEAN;
        t_amount              NUMBER;

        t_feeobjectid         NUMBER;
        t_feeid               NUMBER;
        t_feedescription      VARCHAR2(15);
        t_description         VARCHAR2(15);  -- 03/19/2020 TJL WO 20884
    BEGIN
        a_objectlist   := api.udt_objectlist();

        -- get payment transactions for license number and license type
        sitespecific.pkg_abcsearch.findpaymenttransactions(a_licensenumber => a_licensenumber,
                                                           a_licensetypecode => a_licensetypecode,
                                                           a_objectlist => t_unfilteredobjects);

        FOR inx IN 1 .. t_unfilteredobjects.COUNT
        LOOP
            t_feeobjectid      := api.pkg_columnquery.numericvalue(t_unfilteredobjects(inx).objectid, 'FeeObjId');
            t_description      := api.pkg_columnquery.VALUE(t_feeobjectid, 'Description');  -- 03/19/2020 TJL WO 20884

            -- 12/03/2019 TJL  WO 19946 changed how earned is determined
            t_earned           :=
                (api.pkg_columnquery.datevalue(t_unfilteredobjects(inx).objectid, 'PaymentStatus') IS NOT NULL
             -- If earned amount is less than feeamount there is on overpayment or fee adjustment
             AND (  api.pkg_columnquery.numericvalue(
                        api.pkg_columnquery.numericvalue(t_unfilteredobjects(inx).objectid, 'PaymentStatusObjectId'),
                        'EarnedAmount')
                  * -1) >=
                 (api.pkg_columnquery.numericvalue(t_unfilteredobjects(inx).objectid, 'FeeAmount') * -1));

            t_feeid            := api.pkg_columnquery.VALUE(t_feeobjectid, 'FeeId');

            t_feedescription   :=
                api.pkg_columnquery.VALUE(t_unfilteredobjects(inx).objectid, 'FeeScheduleDescriptionForGrid');

            -- check if transfered
            -- get fee amount and transfer amount and if equal set transfer to true
            --   to prevent the fee being added to list
            SELECT NVL(
                       SUM(
                             api.pkg_columnquery.VALUE(r.relationshipid, 'Amount')
                           -  -- moveAmount,
                             api.pkg_columnquery.VALUE(r.toobjectid, 'FeeAmount')),
                       -1)
              INTO t_amount
              FROM api.relationships r
             WHERE r.endpointid = api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentTransaction')
               AND r.toobjectid = t_unfilteredobjects(inx).objectid;

            t_transfered       := CASE WHEN t_amount = 0 THEN TRUE ELSE FALSE END;

            IF ((NOT t_earned
             AND NOT t_transfered
             AND t_feedescription != 'SRV')  -- 03/19/2020 TJL WO 20884
             OR (t_feedescription = 'OVR'
              OR (t_feedescription = 'SRV'
              AND t_feedescription = t_description  -- 03/19/2020 TJL WO 20884
              AND NOT t_earned))) THEN
                a_objectlist.EXTEND(1);
                a_objectlist(a_objectlist.COUNT)   := api.udt_object(t_unfilteredobjects(inx).objectid);
            END IF;
        END LOOP;
    END findpaymenttransunearned;


    /**************************************************************************************************
        * FindPerson() -- PUBLIC
        *   Search for Person Objects
        **************************************************************************************************/
    PROCEDURE findperson(a_name                       VARCHAR2,
                         a_birthdate                  DATE,
                         a_socialsecuritynumber       VARCHAR2,  -- W0 15584
                         a_addressline1               VARCHAR2,
                         a_addressline2               VARCHAR2,
                         a_uscity                     VARCHAR2,
                         a_usstate                    VARCHAR2,
                         a_zipcode                    VARCHAR2,
                         a_keywords                   VARCHAR2,
                         a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                         a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_findperson            NUMBER(9, 0);
        t_count                 NUMBER(9, 0);
        t_overridesearchlimit   VARCHAR2(1);
    BEGIN
        t_overridesearchlimit   := NVL(a_overridesearchlimit, 'N');
        a_objects               := api.udt_objectlist();
        t_unfilteredobjects     := api.udt_objectlist();
        t_findperson            := api.pkg_constantquery.VALUE('FINDPERSON');

        extension.pkg_cxproceduralsearch.initializesearch('o_Person');
        extension.pkg_cxproceduralsearch.searchbykeywords(   a_name
                                                          || '%');
        extension.pkg_cxproceduralsearch.searchbyindex('SocialSecurityNumber',
                                                       a_socialsecuritynumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('BirthDate', a_birthdate, a_birthdate);
        extension.pkg_cxproceduralsearch.filterobjects('AddressLine1',
                                                       a_addressline1,
                                                       a_addressline1,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('AddressLine2',
                                                       a_addressline2,
                                                       a_addressline2,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('USCity',
                                                       a_uscity,
                                                       a_uscity,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.filterobjects('USState',
                                                       a_usstate,
                                                       a_usstate,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.filterobjects('ZipCode',
                                                       a_zipcode,
                                                       a_zipcode,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbykeywords(a_keywords);

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF t_overridesearchlimit = 'Y' THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            t_count   := t_unfilteredobjects.COUNT;

            IF t_count <= t_findperson THEN
                a_objects   := t_unfilteredobjects;
            ELSE
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_findperson
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        END IF;

        t_unfilteredobjects.delete;
    END findperson;

    -------------------------------------------
    PROCEDURE findprocesses(a_jobid                      udt_id,
                            a_startdate                  DATE,
                            a_enddate                    DATE,
                            a_includeincomplete          VARCHAR2,
                            a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_startdate           DATE;
        t_enddate             DATE;
        t_includeincomplete   VARCHAR2(1);
        t_processesnumber     NUMBER;
        t_count               NUMBER;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_startdate           := NVL(a_startdate, ADD_MONTHS(SYSDATE, -12));
        t_includeincomplete   := NVL(a_includeincomplete, 'Y');
        t_enddate             := TRUNC(a_enddate + 1);

        -- If we are to include incomplete processes, get all processes created within the last year, and all incomplete ones
        IF t_includeincomplete = 'Y' THEN
            SELECT api.udt_object(p.processid)
              BULK COLLECT INTO a_objects
              FROM api.processes p
             WHERE p.jobid = a_jobid
               AND (p.createddate >= t_startdate
                 OR p.outcome IS NULL);
        -- If we are not to get incompleted processes, only get processes created within the date range
        ELSIF t_includeincomplete = 'N' THEN
            t_processesnumber   := api.pkg_constantquery.VALUE('FINDPROCESSES');

            SELECT api.udt_object(p.processid)
              BULK COLLECT INTO a_objects
              FROM api.processes p
             WHERE p.jobid = a_jobid
               AND ((a_startdate IS NOT NULL
                 AND t_enddate IS NOT NULL
                 AND p.createddate BETWEEN a_startdate AND t_enddate)
                 OR (a_startdate IS NULL
                 AND t_enddate IS NOT NULL
                 AND p.createddate <= t_enddate)
                 OR (a_startdate IS NOT NULL
                 AND t_enddate IS NULL
                 AND p.createddate >= a_startdate))
               AND p.outcome IS NOT NULL;

            IF a_objects.COUNT > t_processesnumber THEN
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_processesnumber
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        END IF;
    END findprocesses;

    ------------------------------------------
    PROCEDURE findprotestant(a_jobid                      NUMBER,
                             a_lastname                   VARCHAR2,
                             a_firstname                  VARCHAR2,
                             a_addressline1               VARCHAR2,
                             a_city                       VARCHAR2,
                             a_state                      VARCHAR2,
                             a_zipcode                    VARCHAR2,
                             a_statusreason               VARCHAR2,
                             a_notificationdatefrom       DATE,
                             a_notificationdateto         DATE,
                             a_username                   VARCHAR2,
                             a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_findprotestant      NUMBER(9, 0);
        t_count               NUMBER(9, 0);
        t_includeid           NUMBER;
        t_jobtypeid           NUMBER;
        t_appjobtype          NUMBER;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_appjobtype          := api.pkg_configquery.objectdefidforname('j_Application');

        SELECT jobtypeid
          INTO t_jobtypeid
          FROM api.jobs
         WHERE jobid = a_jobid;

        IF t_jobtypeid = t_appjobtype THEN
            SELECT api.udt_object(r.protestantobjectid)
              BULK COLLECT INTO a_objects
              FROM query.r_applicationprotestant r
             WHERE r.applicationjobid = a_jobid;
        ELSE
            SELECT api.udt_object(r2.protestantobjectid)
              BULK COLLECT INTO a_objects
              FROM query.r_licenseprotestant r2
             WHERE r2.licensejobid = a_jobid;
        END IF;

        IF a_lastname IS NOT NULL
        OR a_firstname IS NOT NULL
        OR a_addressline1 IS NOT NULL
        OR a_city IS NOT NULL
        OR a_state IS NOT NULL
        OR a_zipcode IS NOT NULL
        OR a_statusreason IS NOT NULL
        OR a_notificationdatefrom IS NOT NULL
        OR a_notificationdateto IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.initializesearch('o_Protestant');
            extension.pkg_cxproceduralsearch.searchbyindex('LastName',
                                                           a_lastname,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('FirstName',
                                                           a_firstname,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('dup_AddressLine1',
                                                           a_addressline1,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('dup_City',
                                                           a_city,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('dup_State',
                                                           a_state,
                                                           NULL,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.searchbyindex('dup_ZipCode',
                                                           a_zipcode,
                                                           NULL,
                                                           TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex('StatusReason',
                                                           a_statusreason,
                                                           NULL,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.searchbyindex('NotificationDate',
                                                           a_notificationdatefrom,
                                                           a_notificationdateto);
            extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

            FOR c IN 1 .. a_objects.COUNT
            LOOP
                BEGIN
                    SELECT p.objectid
                      INTO t_includeid
                      FROM query.o_protestant p
                     WHERE p.objectid = a_objects(c).objectid
                       AND p.lastname IS NULL
                       AND p.firstname IS NULL
                       AND p.dup_addressline1 IS NULL
                       AND p.dup_city IS NULL
                       AND p.dup_state IS NULL
                       AND p.dup_zipcode IS NULL;

                    t_unfilteredobjects.EXTEND;
                    t_unfilteredobjects(t_unfilteredobjects.LAST).objectid   := t_includeid;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                END;
            END LOOP;

            extension.pkg_collectionutils.join(a_objects, t_unfilteredobjects);

            t_unfilteredobjects.delete;
        END IF;

        IF a_username IS NOT NULL THEN
            -- Write the search results to the relationship table
            IF t_jobtypeid = t_appjobtype THEN
                DELETE applicationprotestant_t t
                 WHERE t.applicationjobid = a_jobid
                   AND t.username = a_username;
            ELSE
                DELETE licenseprotestant_t t
                 WHERE t.licensejobid = a_jobid
                   AND t.username = a_username;
            END IF;

            FOR c IN 1 .. a_objects.COUNT
            LOOP
                IF t_jobtypeid = t_appjobtype THEN
                    INSERT INTO applicationprotestant_t
                         VALUES (a_objects(c).objectid, a_jobid, a_username);
                ELSE
                    INSERT INTO licenseprotestant_t
                         VALUES (a_objects(c).objectid, a_jobid, a_username);
                END IF;
            END LOOP;
        END IF;
    END findprotestant;

    /*---------------------------------------------------------------------------
        * FindAllProtestants() -- Mike Lott
        * Added to allow searching for Protestants without a job constraint.
        *-------------------------------------------------------------------------*/
    PROCEDURE findallprotestants(a_lastname                   VARCHAR2,
                                 a_firstname                  VARCHAR2,
                                 a_addressline1               VARCHAR2,
                                 a_city                       VARCHAR2,
                                 a_state                      VARCHAR2,
                                 a_zipcode                    VARCHAR2,
                                 a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                                 a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_findprotestant        NUMBER(9, 0);
        t_count                 NUMBER(9, 0);
        t_overridesearchlimit   VARCHAR2(1);
    BEGIN
        t_overridesearchlimit   := NVL(a_overridesearchlimit, 'N');
        a_objects               := api.udt_objectlist();
        t_unfilteredobjects     := api.udt_objectlist();
        t_findprotestant        := api.pkg_constantquery.VALUE('FINDPROTESTANT');

        extension.pkg_cxproceduralsearch.initializesearch('o_Protestant');
        extension.pkg_cxproceduralsearch.searchbyindex('LastName',
                                                       a_lastname,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('FirstName',
                                                       a_firstname,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_AddressLine1',
                                                       a_addressline1,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_City',
                                                       a_city,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_State',
                                                       a_state,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ZipCode',
                                                       a_zipcode,
                                                       NULL,
                                                       TRUE);

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF t_overridesearchlimit = 'Y' THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            t_count   := t_unfilteredobjects.COUNT;

            IF t_count <= t_findprotestant THEN
                a_objects   := t_unfilteredobjects;
            ELSE
                api.pkg_errors.raiseerror(-20001,
                                             'More than '
                                          || t_findprotestant
                                          || ' results were found. Please refine your search criteria.');
            END IF;
        END IF;

        t_unfilteredobjects.delete;
    END findallprotestants;  -- END OF FindAllProtestants()

    PROCEDURE findrefundpayment(a_dup_licensenumber          VARCHAR2,
                                a_paymentdate                DATE,
                                a_paymentdateupper           DATE,
                                a_dup_receiptnumber          VARCHAR2,
                                a_batchid                    VARCHAR2,
                                a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_feeamount             NUMBER;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('o_Payment');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                          '%'
                                                       || a_dup_licensenumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentDateStored', a_paymentdate, a_paymentdateupper);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ReceiptNumber',
                                                       a_dup_receiptnumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('BatchPaymentId',
                                                       UPPER(a_batchid),
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        FOR c IN 1 .. t_unfilteredobjects.COUNT
        LOOP
            --Get Fee Amount for
            SELECT SUM(ft.amount)
              INTO t_feeamount
              FROM query.o_payment p
                   JOIN api.paymenttransactions pt
                   ON pt.paymentid = p.paymentid
                   JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                   ON reo.linkvalue = TO_CHAR(pt.transactionid)
                  AND reo.objectdefid = t_paytransobjectdefid
                   JOIN api.feetransactions ft
                   ON ft.transactionid = pt.transactionid  --APatterson: PIP Task 8.5
             WHERE p.objectid = t_unfilteredobjects(c).objectid
               AND pt.voidedbytransactionid IS NULL
               AND p.isdishonored = 'N'
               AND p.isrefundreversed = 'N'
               AND p.cabinincomeind = 'R';

            IF (t_feeamount >= 0) THEN  -- 07/23/2020 TJL  WO 22226 add = to if
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(t_unfilteredobjects(c).objectid);
            END IF;
        END LOOP;

        t_unfilteredobjects.delete;
    END findrefundpayment;

    PROCEDURE findtransferablelicense(a_externalfilenum            VARCHAR2,
                                      a_licenseenames              VARCHAR2,
                                      a_dup_premaddressline1       VARCHAR2,
                                      a_dup_premaddressuscity      VARCHAR2,
                                      a_dup_premzipcode            VARCHAR2,
                                      a_dup_dbas                   VARCHAR2,
                                      a_createddate                DATE,
                                      a_createddateupper           DATE,
                                      a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_include             VARCHAR2(1) := 'N';
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('j_License');

        IF a_createddate IS NOT NULL
        OR a_createddateupper IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         a_createddate,
                                                         a_createddateupper,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL);
        END IF;

        IF a_externalfilenum IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                           a_externalfilenum,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_dup_premaddressline1 IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'AddressLine1',
                                                                  a_dup_premaddressline1,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_premaddressuscity IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'USACity',
                                                                  a_dup_premaddressuscity,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_premzipcode IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'ZipCode',
                                                                  a_dup_premzipcode,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_dup_dbas IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('DBANames',
                                                                  'DBA',
                                                                  a_dup_dbas,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        IF a_licenseenames IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.initializesearch('j_License');
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('PersonLicensee',
                                                                  'dup_FormattedPersonNameSearch',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('CompanyLicensee',
                                                                  'CompanyName',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12PersonLicensee',
                                                                  'dup_FormattedPersonNameSearch',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('P12CompanyLicensee',
                                                                  'CompanyName',
                                                                  a_licenseenames,
                                                                  NULL,
                                                                  TRUE);

            IF t_unfilteredobjects.FIRST IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'and');
            ELSIF t_unfilteredobjects.FIRST IS NULL THEN
                extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'or', 'or');
            END IF;
        END IF;

        -- Filter out Licenses that do not have Active LTs
        FOR c IN 1 .. t_unfilteredobjects.COUNT
        LOOP
            SELECT MAX(api.pkg_columnquery.VALUE(r.licensetypejobid, 'dup_IsTransferable'))
              INTO t_include
              FROM query.r_licenselicensetype r
             WHERE r.licensejobid = t_unfilteredobjects(c).objectid;

            IF t_include = 'N' THEN
                t_unfilteredobjects.delete(c);
            END IF;
        END LOOP;


        a_objects             := t_unfilteredobjects;
        t_unfilteredobjects.delete;
    END findtransferablelicense;

    PROCEDURE findtransmittal(a_status                     VARCHAR2,
                              a_createddate                DATE,
                              a_createddateupper           DATE,
                              a_cashiereddate              DATE,
                              a_cashiereddateupper         DATE,
                              a_externalfilenum            VARCHAR2,
                              a_districtoffice             VARCHAR2,
                              a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_status            VARCHAR2(6);
        t_findtransmittal   NUMBER(9, 0);
        t_count             NUMBER(9, 0);
    BEGIN
        a_objects           := api.udt_objectlist();
        t_findtransmittal   := api.pkg_constantquery.VALUE('FINDTRANSMITTAL');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('j_Transmittal');
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     a_externalfilenum,
                                                     t_status,
                                                     a_createddate,
                                                     a_createddateupper,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_Office',
                                                       a_districtoffice,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('CashieredDate', a_cashiereddate, a_cashiereddateupper);
        extension.pkg_cxproceduralsearch.performsearch(a_objects, 'and', 'none');

        t_count             := a_objects.COUNT;

        IF t_count > t_findtransmittal THEN
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findtransmittal
                                      || ' results were found. Please refine your search criteria.');
        END IF;
    END findtransmittal;

    PROCEDURE findusersbyoffice(a_user                       VARCHAR2,
                                a_officename                 VARCHAR2,
                                a_relatedobjectids   OUT NOCOPY api.udt_objectlist)
    IS
        CURSOR c_users
        IS
            SELECT users.userid
              FROM query.users users
                   JOIN TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindex('Users',
                                                                               'Name',
                                                                                  a_user
                                                                               || '%') AS api.udt_objectlist)) search
                   ON search.objectid = users.userid
             WHERE users.officename = a_officename;

        t_findusersbyoffice   NUMBER(9, 0);
        t_count               NUMBER(9, 0);
    BEGIN
        a_relatedobjectids    := api.udt_objectlist();
        t_findusersbyoffice   := api.pkg_constantquery.VALUE('FINDUSERSBYOFFICE');

        FOR c IN c_users
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(c.userid);
        END LOOP;

        t_count               := a_relatedobjectids.COUNT;

        IF t_count <= t_findusersbyoffice THEN
            NULL;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findusersbyoffice
                                      || ' results were found. Please refine your search criteria.');
        END IF;
    END;

    PROCEDURE finduserprocesses(a_user                       VARCHAR2,
                                a_processtype                VARCHAR2,
                                a_investigations             VARCHAR2,
                                a_jobexternalfilenum         VARCHAR2,
                                a_datecompletedfrom          DATE,
                                a_datecompletedto            DATE,
                                a_relatedobjectids   OUT NOCOPY api.udt_objectlist)
    IS
        t_todolistuserid           NUMBER(9);
        t_searchinguserid          NUMBER(9);
        t_datecompletedfrom        DATE := a_datecompletedfrom;
        t_datecompletedto          DATE := a_datecompletedto;
        t_viewableofficeidlist     udt_idlist;
        t_officefiltereduserlist   udt_objectlist;
        t_finaluserlist            udt_objectlist;
        t_loopcount                NUMBER;
        t_invalidloopcount         NUMBER;

        --set user list to search based on entered user criteria or on the current user when no user criteria is entered.
        CURSOR c_currentuser
        IS
            SELECT users.userid
              FROM api.users users
             WHERE (LOWER(users.name) LIKE
                        LOWER(   a_user
                              || '%')
                AND a_user IS NOT NULL)
                OR (users.userid = t_searchinguserid
                AND a_user IS NULL);
    BEGIN
        IF a_investigations = 'Y'
       AND a_processtype IS NOT NULL THEN
            api.pkg_errors.raiseerror(-20000,
                                      'The Process Type and the Investigations check box cannot both be selected.');
        END IF;

        --Set SearchingUserId to that of the current user.
        t_searchinguserid    := api.pkg_securityquery.effectiveuserid();

        --Set date range when none is specified.
        IF a_datecompletedfrom IS NOT NULL
       AND a_datecompletedto IS NULL THEN
            t_datecompletedto   := SYSDATE;
        ELSIF a_datecompletedfrom IS NULL
          AND a_datecompletedto IS NOT NULL THEN
            t_datecompletedfrom   := TO_DATE('01/01/1900', 'mm/dd/yyyy');
        END IF;

        a_relatedobjectids   := api.udt_objectlist();
        t_finaluserlist      := api.udt_objectlist();

        --if User criteria is specified in the search and the user's access group might allow seeing other users
        --then set the list of acceptible resulting users accordingly.  If those conditions are not met, then set the
        --allowed users to only include the logged in user.
        IF a_user IS NOT NULL
       AND api.pkg_columnquery.VALUE(t_searchinguserid, 'AccessGroupRankNumber') <> 4 THEN
            --when user might be able to view more than it's own todo list, then:
            --Get list of offices that the searching user can see results for.
            finduseroffices(t_searchinguserid, t_viewableofficeidlist);

            t_officefiltereduserlist   := api.udt_objectlist();

            --Create idlist of all users in the searching user's valid offices.
            FOR c IN 1 .. t_viewableofficeidlist.COUNT
            LOOP
                FOR d IN (SELECT u.userid userid
                            FROM query.users u
                           WHERE u.officeidlist LIKE
                                        '%'
                                     || t_viewableofficeidlist(c)
                                     || '%')
                LOOP
                    t_officefiltereduserlist.EXTEND(1);
                    t_officefiltereduserlist(t_officefiltereduserlist.COUNT)   := api.udt_object(d.userid);
                END LOOP;
            END LOOP;

            --Limit above idlist to only those users that the searching user has accessgroup security to see.
            FOR c2 IN 1 .. t_officefiltereduserlist.COUNT
            LOOP
                IF api.pkg_columnquery.VALUE(t_officefiltereduserlist(c2).objectid, 'AccessGroupRankNumber') >=
                   api.pkg_columnquery.VALUE(t_searchinguserid, 'AccessGroupRankNumber') THEN
                    t_finaluserlist.EXTEND(1);
                    t_finaluserlist(t_finaluserlist.COUNT)   := api.udt_object(t_officefiltereduserlist(c2).objectid);
                ELSE
                    NULL;
                END IF;
            END LOOP;  --final valid user idlist.
        ELSE
            --when user can only see own todo list or when no User criteria is entered, then:
            t_finaluserlist.EXTEND(1);
            t_finaluserlist(t_finaluserlist.COUNT)   := api.udt_object(t_searchinguserid);  --final valid user idlist (set to current user.).
        END IF;

        --these details are later used to raise error
        t_loopcount          := 0;
        t_invalidloopcount   := 0;

        --loop through users from search criteria
        FOR r IN c_currentuser
        LOOP
            t_todolistuserid   := r.userid;

            --Verify that user is in valid user list
            FOR c3 IN 1 .. t_finaluserlist.COUNT
            LOOP
                IF t_todolistuserid = t_finaluserlist(c3).objectid THEN
                    --If searched todo list is okay for user to see, return todo list.
                    FOR p
                        IN (SELECT pr.processid
                              FROM api.processassignments pa
                                   JOIN api.processes pr
                                   ON pr.processid = pa.processid
                                   JOIN api.processtypes pt
                                   ON pt.processtypeid = pr.processtypeid
                                   JOIN api.jobs jobs
                                   ON jobs.jobid = pr.jobid
                             WHERE pa.userid = t_todolistuserid
                               AND (a_processtype IS NULL
                                AND NVL(a_investigations, 'N') = 'N'
                                 OR (a_processtype IS NOT NULL
                                 AND pt.description = a_processtype)
                                 OR (a_investigations = 'Y'
                                 AND pt.processtypeid IN
                                         (api.pkg_configquery.objectdefidforname('p_ConductEnforcementInv'),
                                          api.pkg_configquery.objectdefidforname('p_ConductLicenseInvestigation'),
                                          api.pkg_configquery.objectdefidforname('p_ConductAdminInvestigation'),
                                          api.pkg_configquery.objectdefidforname('p_ConductAppInvestigation'))))
                               AND (jobs.externalfilenum LIKE
                                           a_jobexternalfilenum
                                        || '%'
                                 OR a_jobexternalfilenum IS NULL)
                               AND (pr.datecompleted >= t_datecompletedfrom
                                 OR (pr.datecompleted IS NULL
                                 AND t_datecompletedfrom IS NULL))
                               AND (pr.datecompleted < t_datecompletedto + 1
                                 OR (pr.datecompleted IS NULL
                                 AND t_datecompletedto IS NULL)))
                    LOOP
                        a_relatedobjectids.EXTEND(1);
                        a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(p.processid);
                    END LOOP;  --to get User's todo list
                ELSE
                    --Count each time the loop is done when the searching user is not allowed to see a user from the criteria
                    t_invalidloopcount   := t_invalidloopcount + 1;
                END IF;

                t_loopcount   := t_loopcount + 1;  --Count each time the loop is done for all users from the criteria
            END LOOP;
        END LOOP;  --for each user from search criteria

        -- If valid users where entered in the search criteria (the loop was run) but the searching user was not allowed to see any of them, raise error.
        IF t_loopcount = t_invalidloopcount
       AND t_loopcount <> 0 THEN
            api.pkg_errors.raiseerror(
                -20000,
                'You do not have security to view the To-Do List of the user(s) you have searched for.');
        END IF;
    END finduserprocesses;



    PROCEDURE licensetypejobsltsearch(a_licensetypejobid NUMBER,
                                      a_excludeobjectids VARCHAR2,
                                      a_objectlist   OUT api.udt_objectlist)
    IS
        t_excludeobjectlist   api.udt_objectlist;
        t_excludeobjectids    VARCHAR2(1000)
                                  :=    a_excludeobjectids
                                     || ',';
        t_start               NUMBER := 1;
    BEGIN
        t_excludeobjectlist   := api.udt_objectlist();

        -- ********************************************************************
        -- 02/12/2020 TJL  WO 20483 added code to exclude secondary license
        --                            types for license type 75
        --08/18/2021 PK   WO 25997 Add secondary type 58 to master type 75 undoing the changes done by Tim for WO 20483 for only type 58.
        -- ********************************************************************
        IF api.pkg_columnquery.VALUE(a_licensetypejobid, 'LicenseTypeCode') = '75' THEN
            -- if license type 75 exclude the these license types 58,68,77
          --  t_excludeobjectlist.EXTEND(1);
          --  t_excludeobjectlist(t_excludeobjectlist.COUNT)   := api.udt_object('7970');  --58 
            t_excludeobjectlist.EXTEND(1);
            t_excludeobjectlist(t_excludeobjectlist.COUNT)   := api.udt_object('7965');  -- 68
            t_excludeobjectlist.EXTEND(1);
            t_excludeobjectlist(t_excludeobjectlist.COUNT)   := api.udt_object('7930');  -- 77
        END IF;

        -- ********************************************************************

        WHILE INSTR(t_excludeobjectids, ',', t_start) > 0
          AND a_excludeobjectids IS NOT NULL
        LOOP
            t_excludeobjectlist.EXTEND(1);
            t_excludeobjectlist(t_excludeobjectlist.COUNT)   :=
                api.udt_object(
                    SUBSTR(t_excludeobjectids, t_start, INSTR(t_excludeobjectids, ',', t_start) - t_start));
            t_start   := INSTR(t_excludeobjectids, ',', t_start) + 2;
        END LOOP;

        a_objectlist          := api.udt_objectlist();

        FOR c
            IN (SELECT a.licensetypecategoryobjectid
                  FROM query.r_availablesltforlicense a
                 WHERE a.licensetypeid = a_licensetypejobid
                   AND a.licensetypecategoryobjectid NOT IN
                           (SELECT objectid FROM TABLE(CAST(t_excludeobjectlist AS api.udt_objectlist))))
        LOOP
            a_objectlist.EXTEND(1);
            a_objectlist(a_objectlist.COUNT)   := api.udt_object(c.licensetypecategoryobjectid);
        END LOOP;
    END licensetypejobsltsearch;

    PROCEDURE pltobjectsecondaryltsearch(a_primaryltobjectid NUMBER, a_objectlist OUT api.udt_objectlist)
    IS
    BEGIN
        a_objectlist   := api.udt_objectlist();

        FOR c IN (SELECT e.toobjectid licensetypecategoryobjectid
                    FROM api.relationships b
                         JOIN api.relationships e
                         ON e.fromobjectid = b.toobjectid
                        AND e.endpointid = 298315
                   WHERE b.endpointid = 350009
                     AND b.fromobjectid = a_primaryltobjectid
                     -- 02/12/2020 TJL 20483  Added filter for license type 75 to exclude certain license types
                     AND ((api.pkg_columnquery.VALUE(b.toobjectid, 'LicenseTypeCode') = '75'
                       AND api.pkg_columnquery.VALUE(e.toobjectid, 'LicenseTypeCode') NOT IN ('68', '77')) -- PK   WO 25997 Add secondary type 58 to master type 75 undoing the changes done by Tim for WO 20483 for only type 58.
                       OR api.pkg_columnquery.VALUE(b.toobjectid, 'LicenseTypeCode') != '75'))
        LOOP
            a_objectlist.EXTEND(1);
            a_objectlist(a_objectlist.COUNT)   := api.udt_object(c.licensetypecategoryobjectid);
        END LOOP;
    END pltobjectsecondaryltsearch;

    /**************************************************************************************************
        * PaymentSearch() -- PUBLIC
        *   This procedure will find Payments for the given criteria
        **************************************************************************************************/
    PROCEDURE paymentsearch(a_office                     NUMBER,  -- ObjectId of the Office Object
                            a_paymentdate                DATE,
                            a_paymentdateupper           DATE,
                            a_payeereference             VARCHAR2,
                            a_paymentamount              NUMBER,
                            a_payeename                  VARCHAR2,
                            a_sequencenum                VARCHAR2,
                            a_paymentmethod              NUMBER,  -- ObjectId of the PaymentMethod Object
                            a_transmittalid              VARCHAR2,
                            a_licensenumber              VARCHAR2,
                            a_receiptnumber              VARCHAR2,
                            a_depositnumber              NUMBER,
                            a_override                   VARCHAR2,
                            a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_paymentsearch       NUMBER(9, 0);
        t_count               NUMBER(9, 0);
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_paymentsearch       := api.pkg_constantquery.VALUE('PAYMENTSEARCH');

        extension.pkg_cxproceduralsearch.initializesearch('o_Payment');
        extension.pkg_cxproceduralsearch.searchbyindex('PayeeReference',
                                                       a_payeereference,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentAmountStored',
                                                       a_paymentamount,
                                                       NULL,
                                                       FALSE);  -- not sure if it should have a wild card or not.
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PaymentMethod',
                                                              'ObjectId',
                                                              a_paymentmethod,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Transmittal',
                                                              'ExternalFileNum',
                                                              a_transmittalid,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Office',
                                                              'ObjectId',
                                                              a_office,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PaymentTransactions',
                                                              'HQReceipt',
                                                              a_sequencenum,
                                                              NULL,
                                                              TRUE);  -- added by KL 03_18_10
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentDateStored', a_paymentdate, a_paymentdateupper);
        extension.pkg_cxproceduralsearch.searchbykeywords(   a_payeename
                                                          || '%');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ReceiptNumber',
                                                       a_receiptnumber,
                                                       NULL,
                                                       TRUE);

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                              '%'
                                                           || a_licensenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.searchbyrelatedindex('TDeposit',
                                                              'DepositNumber',
                                                              a_depositnumber,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('o_Payment');
        extension.pkg_cxproceduralsearch.searchbyindex('PayeeReference',
                                                       a_payeereference,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentAmountStored',
                                                       a_paymentamount,
                                                       NULL,
                                                       TRUE);  -- not sure if it should have a wild card or not.
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PaymentMethod',
                                                              'ObjectId',
                                                              a_paymentmethod,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Transmittal',
                                                              'ExternalFileNum',
                                                              a_transmittalid,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Office',
                                                              'ObjectId',
                                                              a_office,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PaymentTransactions',
                                                              'HQReceipt',
                                                              a_sequencenum,
                                                              NULL,
                                                              TRUE);  -- added by KL 03_18_10
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentDateStored', a_paymentdate, a_paymentdateupper);
        extension.pkg_cxproceduralsearch.searchbykeywords(   a_payeename
                                                          || '%');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ReceiptNumber',
                                                       a_receiptnumber,
                                                       NULL,
                                                       TRUE);

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                              '%'
                                                           || a_licensenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PDeposit',
                                                              'DepositNumber',
                                                              a_depositnumber,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        t_count               := t_unfilteredobjects.COUNT;

        IF t_count <= t_paymentsearch
        OR a_override = 'Y' THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_paymentsearch
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
    END paymentsearch;

    ---------------------------------------------------------------
    -- PaymentJobSearch()
    -- This procedure will find Payments for the given criteria
    -- This will limit out the Refunded, Negative, and Dishonored payments.
    -- This is used mainly on the Dishonor Payment(s) Job.
    ---------------------------------------------------------------

    PROCEDURE paymentjobsearch(a_office                     VARCHAR2,
                               a_paymentdate                DATE,
                               a_paymentdateupper           DATE,
                               a_payeereference             VARCHAR2,
                               a_paymentamount              NUMBER,
                               a_payeename                  VARCHAR2,
                               a_sequencenum                VARCHAR2,
                               a_paymentmethod              VARCHAR2,
                               a_transmittalid              VARCHAR2,
                               a_licensenumber              VARCHAR2,
                               a_receiptnumber              VARCHAR2,
                               a_depositnumber              NUMBER,
                               a_currentobjectids           VARCHAR2,
                               a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_excludeobjectlist   api.udt_objectlist;
        t_excludeobjectids    VARCHAR2(1000)
                                  :=    a_currentobjectids
                                     || ',';
        t_start               NUMBER := 1;
        t_exclude             VARCHAR2(1) DEFAULT 'N';
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        t_excludeobjectlist   := api.udt_objectlist();

        WHILE INSTR(t_excludeobjectids, ',', t_start) > 0
          AND a_currentobjectids IS NOT NULL
        LOOP
            t_excludeobjectlist.EXTEND(1);
            t_excludeobjectlist(t_excludeobjectlist.COUNT)   :=
                api.udt_object(
                    SUBSTR(t_excludeobjectids, t_start, INSTR(t_excludeobjectids, ',', t_start) - t_start));
            t_start   := INSTR(t_excludeobjectids, ',', t_start) + 2;
        END LOOP;

        extension.pkg_cxproceduralsearch.initializesearch('o_Payment');
        extension.pkg_cxproceduralsearch.searchbyindex('PayeeReference',
                                                       a_payeereference,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentAmountStored',
                                                       a_paymentamount,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PaymentMethod',
                                                              'Code',
                                                              a_paymentmethod,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Transmittal',
                                                              'ExternalFileNum',
                                                              a_transmittalid,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Office',
                                                              'dup_Office',
                                                              a_office,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PaymentTransactions',
                                                              'HQReceipt',
                                                              a_sequencenum,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentDateStored', a_paymentdate, a_paymentdateupper);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_PayeeName',
                                                       a_payeename,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ReceiptNumber',
                                                       a_receiptnumber,
                                                       NULL,
                                                       TRUE);

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                              '%'
                                                           || a_licensenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.searchbyrelatedindex('TDeposit',
                                                              'DepositNumber',
                                                              a_depositnumber,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        extension.pkg_cxproceduralsearch.initializesearch('o_Payment');
        extension.pkg_cxproceduralsearch.searchbyindex('PayeeReference',
                                                       a_payeereference,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentAmountStored',
                                                       a_paymentamount,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PaymentMethod',
                                                              'Code',
                                                              a_paymentmethod,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Transmittal',
                                                              'ExternalFileNum',
                                                              a_transmittalid,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Office',
                                                              'dup_Office',
                                                              a_office,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PaymentTransactions',
                                                              'HQReceipt',
                                                              a_sequencenum,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentDateStored', a_paymentdate, a_paymentdateupper);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_PayeeName',
                                                       a_payeename,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ReceiptNumber',
                                                       a_receiptnumber,
                                                       NULL,
                                                       TRUE);

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                              '%'
                                                           || a_licensenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PDeposit',
                                                              'DepositNumber',
                                                              a_depositnumber,
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'or');

        FOR c IN 1 .. t_unfilteredobjects.COUNT
        LOOP
            --if IsRefund exclude
            --if IsDishonor exclude
            --if less then or equal to zero exclude
            IF api.pkg_columnquery.VALUE(t_unfilteredobjects(c).objectid, 'IsRefund') = 'N'
           AND api.pkg_columnquery.VALUE(t_unfilteredobjects(c).objectid, 'IsDishonored') = 'N'
           AND api.pkg_columnquery.VALUE(t_unfilteredobjects(c).objectid, 'PaymentAmountforDisplay') > 0 THEN
                FOR c_1 IN 1 .. t_excludeobjectlist.COUNT
                LOOP
                    IF t_excludeobjectlist(c_1).objectid = t_unfilteredobjects(c).objectid THEN
                        t_exclude   := 'Y';
                    ELSE
                        t_exclude   := 'N';
                    END IF;

                    EXIT WHEN t_exclude = 'Y';
                END LOOP;

                IF t_exclude = 'N' THEN
                    a_objects.EXTEND(1);
                    a_objects(a_objects.COUNT)   := api.udt_object(t_unfilteredobjects(c).objectid);
                END IF;
            END IF;
        END LOOP;

        --a_Objects := t_UnfilteredObjects;
        t_unfilteredobjects.delete;
    END paymentjobsearch;

    PROCEDURE finddishonoredpayment(a_dup_licensenumber          VARCHAR2,
                                    a_paymentdate                DATE,
                                    a_paymentdateupper           DATE,
                                    a_dup_receiptnumber          VARCHAR2,
                                    a_batchid                    VARCHAR2,
                                    a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects     api.udt_objectlist;
        t_feeamount             NUMBER;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('o_Payment');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                          '%'
                                                       || a_dup_licensenumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('PaymentDateStored', a_paymentdate, a_paymentdateupper);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_ReceiptNumber',
                                                       a_dup_receiptnumber,
                                                       NULL,
                                                       TRUE);
        --extension.pkg_cxproceduralsearch.SearchByIndex('BatchPaymentId', upper(a_BatchId), null, true);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Dishonor',
                                                              'BatchId',
                                                              UPPER(a_batchid),
                                                              NULL,
                                                              TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');

        FOR c IN 1 .. t_unfilteredobjects.COUNT
        LOOP
            --Get Fee Amount for
            SELECT SUM(ft.amount)
              INTO t_feeamount
              FROM query.o_payment p
                   JOIN api.paymenttransactions pt
                   ON pt.paymentid = p.paymentid
                   JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                   ON reo.linkvalue = TO_CHAR(pt.transactionid)
                  AND reo.objectdefid = t_paytransobjectdefid
                   JOIN api.feetransactions ft
                   ON ft.transactionid = pt.transactionid  --APatterson: PIP Task 8.5
             WHERE p.objectid = t_unfilteredobjects(c).objectid
               AND pt.voidedbytransactionid IS NULL
               AND p.isdishonored = 'N'
               AND p.isrefundreversed = 'N'
               AND p.cabinincomeind = 'D'
               AND p.isdishonoredreversed = 'N';

            IF (t_feeamount > 0) THEN
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(t_unfilteredobjects(c).objectid);
            END IF;
        END LOOP;

        t_unfilteredobjects.delete;
    END finddishonoredpayment;

    /**************************************************************************************************
        * FindCatererEventAuths() -- PUBLIC
        *   This procedure finds all the Caterer/Event Permit Auth Processes based on the specified criteria
        * Updated 10/23/2015 by Ryan Lutz for performance
        -- 05/01/2024 PK   WO35704  Added LSPID to search screen Caterer/Event Auth Search
        **************************************************************************************************/
    PROCEDURE findcaterereventauths(a_licensenumber              VARCHAR2,
                                    a_licenseenames              VARCHAR2,
                                    a_lspid                      VARCHAR2,
                                    a_dateofeventfrom            DATE,
                                    a_dateofeventto              DATE,
                                    a_eventlocationaddressline1  VARCHAR2,
                                    a_eventlocationcity          VARCHAR2,
                                    a_eventlocationzip           VARCHAR2,
                                    a_conditionalonly            VARCHAR2,
                                    a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_searchjobs          api.udt_objectlist;
        t_unfilteredobjects   api.udt_objectlist;
        t_caterereventauths   api.udt_objectlist;
    BEGIN
        a_objects             := api.udt_objectlist();
        t_caterereventauths   := api.udt_objectlist();


        -- Find all Licenses and Applications based on License Number and Licensee Names
        findlicenseandapplication(a_licensenumber,
                                  NULL,
                                  a_licenseenames,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  'Y',
                                  t_unfilteredobjects);
        t_searchjobs          := t_unfilteredobjects;

        --Find all License Types based on License Number and Licensee Names
        findlicensetype(NULL,
                        NULL,
                        a_licensenumber,
                        a_licenseenames,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        'Y',
                        t_unfilteredobjects);
        extension.pkg_collectionutils.append(t_searchjobs, t_unfilteredobjects);

        -- Find all CatererEventAuths for the jobs found
        FOR c IN (SELECT processid
                    FROM query.p_issuecaterereventauth cea
                         JOIN TABLE(CAST(t_searchjobs AS api.udt_objectlist)) jo
                         ON jo.objectid = cea.jobid)
        LOOP
            t_caterereventauths.EXTEND(1);
            t_caterereventauths(t_caterereventauths.COUNT)   := api.udt_object(c.processid);
        END LOOP;
        
         --Find all Issue Caterer/Event Auths by LSPID
         -- 05/01/2024 PK   WO35704  Added LSPID to search screen Caterer/Event Auth Search
         extension.pkg_cxproceduralsearch.initializesearch('p_IssueCatererEventAuth');
         
        IF a_lspid IS NOT NULL THEN 
           -- extension.pkg_cxproceduralsearch.initializesearch('p_IssueCatererEventAuth');
            extension.pkg_cxproceduralsearch.searchbyindex('LSPId', a_lspid, NULL, TRUE);
        END IF;
            
        -- Find all Issue Caterer/Event Auths by date of event

        IF (a_dateofeventfrom IS NOT NULL
         OR a_dateofeventto IS NOT NULL) THEN
          --  extension.pkg_cxproceduralsearch.initializesearch('p_IssueCatererEventAuth');
            extension.pkg_cxproceduralsearch.searchbyindex('DateOfEventFrom', a_dateofeventfrom, a_dateofeventto);
            extension.pkg_cxproceduralsearch.searchbyindex('DateOfEventTo', a_dateofeventfrom, a_dateofeventto);
     
         end if;
            IF a_licensenumber IS NOT NULL
            OR a_licenseenames IS NOT NULL THEN
                extension.pkg_cxproceduralsearch.performsearch(t_caterereventauths, 'or', 'and');
            ELSE
                extension.pkg_cxproceduralsearch.performsearch(t_caterereventauths, 'or', 'none');
          --  END IF;
        END IF;

        a_objects             := t_caterereventauths;
        t_caterereventauths.delete;
        

        -- Find all Licenses and Applications based on premises address and get Caterer/Event Auths for them
        findlicenseandapplication(NULL,
                                  NULL,
                                  NULL,
                                  a_eventlocationaddressline1,
                                  NULL,
                                  a_eventlocationcity,
                                  a_eventlocationzip,
                                  NULL,
                                  NULL,
                                  NULL,
                                  NULL,
                                  'Y',
                                  t_searchjobs);

        FOR c IN (SELECT processid
                    FROM query.p_issuecaterereventauth cea
                         JOIN TABLE(CAST(t_searchjobs AS api.udt_objectlist)) jo
                         ON jo.objectid = cea.jobid)
        LOOP
            IF api.pkg_columnquery.VALUE(c.processid, 'EventLocationSameAsPremises') = 'Y' THEN
                t_caterereventauths.EXTEND(1);
                t_caterereventauths(t_caterereventauths.COUNT)   := api.udt_object(c.processid);
            END IF;
        END LOOP;

        -- Find all Issue Caterer/Event Auths by location
        extension.pkg_cxproceduralsearch.initializesearch('p_IssueCatererEventAuth');

        IF a_eventlocationaddressline1 IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('EventLocation',
                                                                  'AddressLine1',
                                                                  a_eventlocationaddressline1,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_eventlocationcity IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('EventLocation',
                                                                  'USACity',
                                                                  a_eventlocationcity,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_eventlocationzip IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('EventLocation',
                                                                  'ZipCode',
                                                                  a_eventlocationzip,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF t_caterereventauths.FIRST IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.performsearch(t_caterereventauths, 'and', 'or');
        ELSE
            extension.pkg_cxproceduralsearch.performsearch(t_caterereventauths, 'and', 'none');
        END IF;

        IF (a_licensenumber IS NOT NULL
         OR a_licenseenames IS NOT NULL
         OR a_lspid IS NOT NULL
         OR a_dateofeventfrom IS NOT NULL
         OR a_dateofeventto IS NOT NULL)
       AND (a_eventlocationaddressline1 IS NOT NULL
         OR a_eventlocationcity IS NOT NULL
         OR a_eventlocationzip IS NOT NULL) THEN
            extension.pkg_collectionutils.join(a_objects, t_caterereventauths);
        ELSIF (a_eventlocationaddressline1 IS NOT NULL
            OR a_eventlocationcity IS NOT NULL
            OR a_eventlocationzip IS NOT NULL) THEN
            a_objects   := t_caterereventauths;
        END IF;

        IF a_conditionalonly = 'Y' THEN
            t_unfilteredobjects   := a_objects;
            a_objects.delete;

            FOR i IN 1 .. t_unfilteredobjects.COUNT
            LOOP
                IF api.pkg_columnquery.VALUE(t_unfilteredobjects(i).objectid, 'Conditional') = 'Y' THEN
                    a_objects.EXTEND(1);
                    a_objects(a_objects.COUNT)   := t_unfilteredobjects(i);
                END IF;
            END LOOP;
        END IF;
    END;

    /**************************************************************************************************
            * FindInspection() -- PUBLIC
            *   This procedure finds all the Impact Inspection based on the specified criteria
            * Created 01/28/2019 By Pawanjit Kaur WO 13953 Added Search Functionality For Impact Inspections
       **************************************************************************************************/

    PROCEDURE findinspection(a_office                     NUMBER,
                             a_inspectionnumber           VARCHAR2,
                             a_abcreportnumber            VARCHAR2,
                             a_inspectiontype             VARCHAR2,
                             a_agent                      VARCHAR2,
                             a_licensenumber              VARCHAR2,
                             a_addressline1               VARCHAR2,
                             a_city                       VARCHAR2,
                             a_state                      VARCHAR2,
                             a_zipcode                    VARCHAR2,
                             a_status                     VARCHAR2,
                             a_createdstartdate           DATE,
                             a_createdenddate             DATE,
                             a_completedstartdate         DATE,
                             a_completedenddate           DATE,
                             a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_status              VARCHAR2(6);
        t_count               NUMBER(9, 0);
        t_objectlist          api.udt_objectlist;
        t_findinspection      NUMBER(9, 0);
    BEGIN
        a_objects             := api.udt_objectlist();
        t_unfilteredobjects   := api.udt_objectlist();
        t_objectlist          := api.udt_objectlist();
        t_findinspection      := api.pkg_constantquery.VALUE('FINDINSPECTION');

        extension.pkg_cxproceduralsearch.initializesearch('j_Inspection');

        IF a_status IS NOT NULL THEN
            BEGIN
                SELECT s.tag
                  INTO t_status
                  FROM api.statuses s
                 WHERE s.description = a_status;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Multiple statuses defined in configuration for description '
                                              || a_status);
            END;
        END IF;

        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     t_status,
                                                     a_createdstartdate,
                                                     a_createdenddate,
                                                     NULL,
                                                     NULL,
                                                     a_completedstartdate,
                                                     a_completedenddate);

        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Office',
                                                              'ObjectId',
                                                              a_office,
                                                              NULL,
                                                              TRUE);

        extension.pkg_cxproceduralsearch.searchbyindex('dup_InspectionNumber',
                                                       a_inspectionnumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('ImpactInspectionReportNumber',
                                                       a_abcreportnumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('InspectionType',
                                                       a_inspectiontype,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_Investigators',
                                                       a_agent,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                       a_licensenumber,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicensePremiseAddressLine1',
                                                       a_addressline1,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicensePremiseCity',
                                                       a_city,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicensePremiseZipCode',
                                                       a_zipcode,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyrelatedindex('PremisesAddress',
                                                              'USAState',
                                                              a_state,
                                                              NULL,
                                                              FALSE);

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects, 'and', 'none');



        t_count               := t_unfilteredobjects.COUNT;

        IF t_count <= t_findinspection THEN
            a_objects   := t_unfilteredobjects;
        ELSE
            api.pkg_errors.raiseerror(-20001,
                                         'More than '
                                      || t_findinspection
                                      || ' results were found. Please refine your search criteria.');
        END IF;

        t_unfilteredobjects.delete;
    END findinspection;

    ---------------------------------------------------------
    --  StaffUiFindPaymentTransUnearn() -- PUBLIC
    --  Wrapper procedure for FindPaymentTransUnearned.
    --  Allows results of FindPaymentTransUnearned to be used in the StaffUI system.
    ---------------------------------------------------------
    PROCEDURE staffuifindpaymenttransunearn(a_rownum           number,
                                             a_licensenumber    VARCHAR2,
                                             a_licensetypecode  VARCHAR2)
    IS
        t_objectlist        api.udt_objectlist;
        t_searchresults     api.pkg_definition.udt_searchresults;
        t_objectsreturned   boolean;
    BEGIN
        t_objectlist        := api.udt_objectlist();
        sitespecific.pkg_abcsearch.findpaymenttransunearned(a_licensenumber, a_licensetypecode, t_objectlist);
        t_objectsreturned := api.pkg_search.intersectobjectlist(t_objectlist, t_searchresults);
        api.pkg_search.writesearchresults(t_searchresults);
    END staffuifindpaymenttransunearn;
END pkg_abcsearch;
/
