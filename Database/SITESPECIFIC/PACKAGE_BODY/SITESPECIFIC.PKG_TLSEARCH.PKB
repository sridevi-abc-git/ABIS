CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_tlsearch
IS
    -- **************************************************************************
    -- File:        PKG_TLSEARCH.PKB
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

    PROCEDURE findleadclass(a_trainer                    VARCHAR2,
                            a_district                   VARCHAR2,
                            a_agency                     VARCHAR2,
                            a_location                   VARCHAR2,
                            a_trainingdate               DATE,
                            a_trainingdateupper          DATE,
                            a_confirmnum                 NUMBER,
                            a_studentemail               VARCHAR2,
                            a_studentname                VARCHAR2,
                            a_phonenumber                NUMBER,
                            a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();


        extension.pkg_cxproceduralsearch.initializesearch(
            'o_TL_LEADClassInfo');

        IF a_trainingdate IS NOT NULL
        OR a_trainingdateupper IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'TrainingDate',
                a_trainingdate,
                a_trainingdateupper);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_Agency',
                                                           a_agency,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_phonenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'RequesterPhoneNumber',
                a_phonenumber,
                NULL,
                TRUE);
        END IF;

        IF a_trainer IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassTrainer',
                'Name',
                a_trainer,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassLocation',
                'dup_District',
                '%' || a_district,
                NULL,
                TRUE);
        END IF;

        IF a_location IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassLocation',
                'LEADClassAddress',
                a_location,
                NULL,
                TRUE);
        END IF;

        IF a_confirmnum IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassRegistration',
                'ConfirmationNumber',
                a_confirmnum,
                NULL,
                TRUE);
        END IF;

        IF a_studentemail IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassRegistration',
                'EmailAddress',
                a_studentemail,
                NULL,
                TRUE);
        END IF;

        IF a_studentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassRegistration',
                'StudentName',
                a_studentname,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findleadclass;

    PROCEDURE findleadclass(a_district                   VARCHAR2,
                            a_trainingdate               DATE,
                            a_objects         OUT NOCOPY api.udt_objectlist)
    IS
    BEGIN
        findleadclass(NULL,
                      a_district,
                      NULL,
                      NULL,
                      a_trainingdate,
                      a_trainingdate,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      a_objects);
    END;

    FUNCTION findleadclass(a_trainer       VARCHAR2,
                           a_district      VARCHAR2,
                           a_agency        VARCHAR2,
                           a_location      VARCHAR2,
                           a_trainingdate  DATE,
                           a_trainingdateupper DATE,
                           a_confirmnum    NUMBER,
                           a_studentemail  VARCHAR2,
                           a_studentname   VARCHAR2,
                           a_phonenumber   NUMBER)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();


        extension.pkg_cxproceduralsearch.initializesearch(
            'o_TL_LEADClassInfo');

        IF a_trainingdate IS NOT NULL
        OR a_trainingdateupper IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'TrainingDate',
                a_trainingdate,
                a_trainingdateupper);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_Agency',
                                                           a_agency,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_phonenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'RequesterPhoneNumber',
                a_phonenumber,
                NULL,
                TRUE);
        END IF;

        IF a_trainer IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassTrainer',
                'Name',
                a_trainer,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassLocation',
                'dup_District',
                '%' || a_district,
                NULL,
                TRUE);
        END IF;

        IF a_location IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassLocation',
                'LEADClassAddress',
                a_location,
                NULL,
                TRUE);
        END IF;

        IF a_confirmnum IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassRegistration',
                'ConfirmationNumber',
                a_confirmnum,
                NULL,
                TRUE);
        END IF;

        IF a_studentemail IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassRegistration',
                'EmailAddress',
                a_studentemail,
                NULL,
                TRUE);
        END IF;

        IF a_studentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LEADClassRegistration',
                'StudentName',
                a_studentname,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findleadclass;

    PROCEDURE findtracecase(a_agentname                  VARCHAR2,
                            a_case61number               VARCHAR2,
                            a_district                   VARCHAR2,
                            a_county                     VARCHAR2,
                            a_city                       VARCHAR2,
                            a_dateoccurred               DATE,
                            a_openeddate                 DATE,
                            a_closeddate                 DATE,
                            a_licensenumber              VARCHAR2,
                            a_victim                     VARCHAR2,
                            a_dateoccurredupper          DATE,
                            a_openeddateupper            DATE,
                            a_closeddateupper            DATE,
                            a_status                     VARCHAR2,
                            a_tracetype                  VARCHAR2,
                            a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_agentname IS NULL
       AND a_case61number IS NULL
       AND a_district IS NULL
       AND a_county IS NULL
       AND a_city IS NULL
       AND a_dateoccurred IS NULL
       AND a_openeddate IS NULL
       AND a_closeddate IS NULL
       AND a_licensenumber IS NULL
       AND a_victim IS NULL
       AND a_dateoccurredupper IS NULL
       AND a_openeddateupper IS NULL
       AND a_status IS NULL
       AND a_closeddateupper IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_TRACEData');

        --      extension.pkg_cxproceduralsearch.SearchByIndex('AgentName', a_AgentName, null, true);
        IF a_case61number IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Case61Number',
                                                           a_case61number,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_dateoccurred IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateAccidentEventOccurred',
                a_dateoccurred,
                a_dateoccurredupper);
        END IF;

        IF a_openeddate IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('OpenedDate',
                                                           a_openeddate,
                                                           a_openeddateupper);
        END IF;

        IF a_closeddate IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('ClosedDate',
                                                           a_closeddate,
                                                           a_closeddateupper);
        END IF;

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('LicenseNumber',
                                                           a_licensenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_tracetype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('TRACEType',
                                                           a_tracetype,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_status IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Status',
                                                           a_status,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_victim IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEPrimaryVictim',
                'dup_FormattedName',
                a_victim,
                NULL,
                TRUE);
        END IF;

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECounty',
                'CountyName',
                a_county,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEDistrictOffice',
                'dup_Office',
                '%' || a_district,
                NULL,
                TRUE);
        END IF;

        IF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECity',
                'CityName',
                a_city,
                NULL,
                TRUE);
        END IF;

        IF a_agentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEAgent',
                'Name',
                a_agentname,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findtracecase;

    FUNCTION findtracecase(a_agentname     VARCHAR2,
                           a_case61number  VARCHAR2,
                           a_district      VARCHAR2,
                           a_county        VARCHAR2,
                           a_city          VARCHAR2,
                           a_dateoccurred  DATE,
                           a_openeddate    DATE,
                           a_closeddate    DATE,
                           a_licensenumber VARCHAR2,
                           a_victim        VARCHAR2,
                           a_dateoccurredupper DATE,
                           a_openeddateupper DATE,
                           a_closeddateupper DATE,
                           a_status        VARCHAR2,
                           a_tracetype     VARCHAR2)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_agentname IS NULL
       AND a_case61number IS NULL
       AND a_district IS NULL
       AND a_county IS NULL
       AND a_city IS NULL
       AND a_dateoccurred IS NULL
       AND a_openeddate IS NULL
       AND a_closeddate IS NULL
       AND a_licensenumber IS NULL
       AND a_victim IS NULL
       AND a_dateoccurredupper IS NULL
       AND a_openeddateupper IS NULL
       AND a_closeddateupper IS NULL
       AND a_status IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_TRACEData');

        --      extension.pkg_cxproceduralsearch.SearchByIndex('AgentName', a_AgentName, null, true);
        IF a_case61number IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Case61Number',
                                                           a_case61number,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_dateoccurred IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateAccidentEventOccurred',
                a_dateoccurred,
                a_dateoccurredupper);
        END IF;

        IF a_openeddate IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('OpenedDate',
                                                           a_openeddate,
                                                           a_openeddateupper);
        END IF;

        IF a_closeddate IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('ClosedDate',
                                                           a_closeddate,
                                                           a_closeddateupper);
        END IF;

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('LicenseNumber',
                                                           a_licensenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_tracetype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('TRACEType',
                                                           a_tracetype,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_victim IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEPrimaryVictim',
                'dup_FormattedName',
                a_victim,
                NULL,
                TRUE);
        END IF;

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECounty',
                'CountyName',
                a_county,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEDistrictOffice',
                'dup_Office',
                '%' || a_district,
                NULL,
                TRUE);
        END IF;

        IF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECity',
                'CityName',
                a_city,
                NULL,
                TRUE);
        END IF;

        IF a_agentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEAgent',
                'Name',
                a_agentname,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findtracecase;

    PROCEDURE findtracecheckpoint(
        a_agentname                  VARCHAR2,
        a_district                   VARCHAR2,
        a_county                     VARCHAR2,
        a_city                       VARCHAR2,
        a_location                   VARCHAR2,
        a_agencyhostingcheckpoint    VARCHAR2,
        a_checkpointdate             DATE,
        a_checkpointdateupper        DATE,
        a_tracetype                  VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_agentname IS NULL
       AND a_district IS NULL
       AND a_county IS NULL
       AND a_city IS NULL
       AND a_location IS NULL
       AND a_agencyhostingcheckpoint IS NULL
       AND a_checkpointdate IS NULL
       AND a_checkpointdateupper IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_TRACEData');

        --      extension.pkg_cxproceduralsearch.SearchByIndex('AgentName', a_AgentName, null, true);
        IF a_location IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Location',
                                                           '%' || a_location,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_checkpointdate IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'CheckpointDate',
                a_checkpointdate,
                a_checkpointdateupper);
        END IF;

        IF a_agencyhostingcheckpoint IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'AgencyHostingCheckpoint',
                a_agencyhostingcheckpoint,
                NULL,
                TRUE);
        END IF;

        IF a_tracetype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('TRACEType',
                                                           a_tracetype,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECounty',
                'CountyName',
                a_county,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEDistrictOffice',
                'dup_Office',
                '%' || a_district,
                NULL,
                TRUE);
        END IF;

        IF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECity',
                'CityName',
                a_city,
                NULL,
                TRUE);
        END IF;

        IF a_agentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEAgent',
                'Name',
                a_agentname,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findtracecheckpoint;

    FUNCTION findtracecheckpoint(a_agentname     VARCHAR2,
                                 a_district      VARCHAR2,
                                 a_county        VARCHAR2,
                                 a_city          VARCHAR2,
                                 a_location      VARCHAR2,
                                 a_agencyhostingcheckpoint VARCHAR2,
                                 a_checkpointdate DATE,
                                 a_checkpointdateupper DATE,
                                 a_tracetype     VARCHAR2)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_agentname IS NULL
       AND a_district IS NULL
       AND a_county IS NULL
       AND a_city IS NULL
       AND a_location IS NULL
       AND a_agencyhostingcheckpoint IS NULL
       AND a_checkpointdate IS NULL
       AND a_checkpointdateupper IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_TRACEData');

        --      extension.pkg_cxproceduralsearch.SearchByIndex('AgentName', a_AgentName, null, true);
        IF a_location IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Location',
                                                           '%' || a_location,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_checkpointdate IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'CheckpointDate',
                a_checkpointdate,
                a_checkpointdateupper);
        END IF;

        IF a_agencyhostingcheckpoint IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'AgencyHostingCheckpoint',
                a_agencyhostingcheckpoint,
                NULL,
                TRUE);
        END IF;

        IF a_tracetype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('TRACEType',
                                                           a_tracetype,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECounty',
                'CountyName',
                a_county,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEDistrictOffice',
                'dup_Office',
                '%' || a_district,
                NULL,
                TRUE);
        END IF;

        IF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECity',
                'CityName',
                a_city,
                NULL,
                TRUE);
        END IF;

        IF a_agentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEAgent',
                'Name',
                a_agentname,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findtracecheckpoint;

    PROCEDURE findtracenonavoid(
        a_agentname                  VARCHAR2,
        a_dateoftraining             DATE,
        a_district                   VARCHAR2,
        a_county                     VARCHAR2,
        a_city                       VARCHAR2,
        a_location                   VARCHAR2,
        a_lawenforcementagencytrained VARCHAR2,
        a_communitygrouptrained      VARCHAR2,
        a_eventtrained               VARCHAR2,
        a_dateoftrainingupper        DATE,
        a_tracetype                  VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_agentname IS NULL
       AND a_dateoftraining IS NULL
       AND a_district IS NULL
       AND a_county IS NULL
       AND a_city IS NULL
       AND a_location IS NULL
       AND a_lawenforcementagencytrained IS NULL
       AND a_communitygrouptrained IS NULL
       AND a_eventtrained IS NULL
       AND a_dateoftrainingupper IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_TRACEData');

        --      extension.pkg_cxproceduralsearch.SearchByIndex('AgentName', a_AgentName, null, true);
        IF a_location IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Location',
                                                           a_location,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_dateoftraining IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateOfTraining',
                a_dateoftraining,
                a_dateoftrainingupper);
        END IF;

        IF a_lawenforcementagencytrained IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'LawEnforcementAgencyTrained',
                a_lawenforcementagencytrained,
                NULL,
                TRUE);
        END IF;

        IF a_communitygrouptrained IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'CommunityGroupTrained',
                a_communitygrouptrained,
                NULL,
                TRUE);
        END IF;

        IF a_eventtrained IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('EventTrained',
                                                           a_eventtrained,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_tracetype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('TRACEType',
                                                           a_tracetype,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECounty',
                'CountyName',
                a_county,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEDistrictOffice',
                'dup_Office',
                '%' || a_district,
                NULL,
                TRUE);
        END IF;

        IF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECity',
                'CityName',
                a_city,
                NULL,
                TRUE);
        END IF;

        IF a_agentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEAgent',
                'Name',
                a_agentname,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findtracenonavoid;

    FUNCTION findtracenonavoid(a_agentname     VARCHAR2,
                               a_dateoftraining DATE,
                               a_district      VARCHAR2,
                               a_county        VARCHAR2,
                               a_city          VARCHAR2,
                               a_location      VARCHAR2,
                               a_lawenforcementagencytrained VARCHAR2,
                               a_communitygrouptrained VARCHAR2,
                               a_eventtrained  VARCHAR2,
                               a_dateoftrainingupper DATE,
                               a_tracetype     VARCHAR2)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_agentname IS NULL
       AND a_dateoftraining IS NULL
       AND a_district IS NULL
       AND a_county IS NULL
       AND a_city IS NULL
       AND a_location IS NULL
       AND a_lawenforcementagencytrained IS NULL
       AND a_communitygrouptrained IS NULL
       AND a_eventtrained IS NULL
       AND a_dateoftrainingupper IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_TRACEData');

        --      extension.pkg_cxproceduralsearch.SearchByIndex('AgentName', a_AgentName, null, true);
        IF a_location IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Location',
                                                           a_location,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_dateoftraining IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateOfTraining',
                a_dateoftraining,
                a_dateoftrainingupper);
        END IF;

        IF a_lawenforcementagencytrained IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'LawEnforcementAgencyTrained',
                a_lawenforcementagencytrained,
                NULL,
                TRUE);
        END IF;

        IF a_communitygrouptrained IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'CommunityGroupTrained',
                a_communitygrouptrained,
                NULL,
                TRUE);
        END IF;

        IF a_eventtrained IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('EventTrained',
                                                           a_eventtrained,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_tracetype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('TRACEType',
                                                           a_tracetype,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECounty',
                'CountyName',
                a_county,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEDistrictOffice',
                'dup_Office',
                '%' || a_district,
                NULL,
                TRUE);
        END IF;

        IF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACECity',
                'CityName',
                a_city,
                NULL,
                TRUE);
        END IF;

        IF a_agentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'TRACEAgent',
                'Name',
                a_agentname,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findtracenonavoid;

    PROCEDURE findimpact(a_dateofoperation            DATE,
                         a_licensenumber              VARCHAR2,
                         a_address1line               VARCHAR2,
                         a_dateofoperationupper       DATE,
                         a_district                   VARCHAR2,
                         a_agency                     VARCHAR2,
                         a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_dateofoperation IS NULL
       AND a_licensenumber IS NULL
       AND a_address1line IS NULL
       AND a_dateofoperationupper IS NULL
       AND a_district IS NULL
       AND a_agency IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_GrantData');
        -- Limit to IMPACT Grant Data
        extension.pkg_cxproceduralsearch.searchbyindex('GrantType',
                                                       'IMPACT',
                                                       NULL);

        IF a_dateofoperation IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateOfOperation',
                a_dateofoperation,
                a_dateofoperationupper);
        END IF;

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'LicenseNumber',
                a_licensenumber,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DistrictOfficePDAddress',
                a_district,
                NULL,
                TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Agency',
                'AgencyName',
                a_agency,
                NULL,
                TRUE);
        END IF;

        IF a_address1line IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'Address1Line',
                a_address1line,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('Submitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findimpact;

    FUNCTION findimpact(a_dateofoperation DATE,
                        a_dateofoperationupper DATE,
                        a_licensenumber VARCHAR2,
                        a_address1line  VARCHAR2,
                        a_district      VARCHAR2,
                        a_agency        VARCHAR2)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_dateofoperation IS NULL
       AND a_licensenumber IS NULL
       AND a_address1line IS NULL
       AND a_dateofoperationupper IS NULL
       AND a_district IS NULL
       AND a_agency IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_GrantData');
        -- Limit to IMPACT Grant Data
        extension.pkg_cxproceduralsearch.searchbyindex('GrantType',
                                                       'IMPACT',
                                                       NULL);

        IF a_dateofoperation IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateOfOperation',
                a_dateofoperation,
                a_dateofoperationupper);
        END IF;

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'LicenseNumber',
                a_licensenumber,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DistrictOfficePDAddress',
                a_district,
                NULL,
                TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Agency',
                'AgencyName',
                a_agency,
                NULL,
                TRUE);
        END IF;

        IF a_address1line IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'Address1Line',
                a_address1line,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('Submitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findimpact;

    PROCEDURE findshouldertap(
        a_dateofoperation            DATE,
        a_dateofoperationupper       DATE,
        a_decoyname                  VARCHAR2,
        a_phonenumber                NUMBER,
        a_caseagent                  VARCHAR2,
        a_officersinvolved           VARCHAR2,
        a_district                   VARCHAR2,
        a_agency                     VARCHAR2,
        a_address1line               VARCHAR2,
        a_licensenumber              VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_dateofoperation IS NULL
       AND a_dateofoperationupper IS NULL
       AND a_decoyname IS NULL
       AND a_phonenumber IS NULL
       AND a_caseagent IS NULL
       AND a_officersinvolved IS NULL
       AND a_district IS NULL
       AND a_agency IS NULL
       AND a_address1line IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_GrantData');
        -- Limit to Shoulder Tap Grant Data
        extension.pkg_cxproceduralsearch.searchbyindex('GrantType',
                                                       'Shoulder Tap',
                                                       NULL);

        IF a_dateofoperation IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateOfOperation',
                a_dateofoperation,
                a_dateofoperationupper);
        END IF;

        IF a_decoyname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('DecoyName',
                                                           a_decoyname,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_phonenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('PhoneNumber',
                                                           a_phonenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_caseagent IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('CaseAgent',
                                                           a_caseagent,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_officersinvolved IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'OfficersInvolved',
                '%' || a_officersinvolved || '%',
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DistrictOfficePDAddress',
                a_district,
                NULL,
                TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Agency',
                'AgencyName',
                a_agency,
                NULL,
                TRUE);
        END IF;

        IF a_address1line IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'Address1Line',
                a_address1line,
                NULL,
                TRUE);
        END IF;

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'LicenseNumber',
                a_licensenumber,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('Submitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findshouldertap;

    FUNCTION findshouldertap(a_dateofoperation DATE,
                             a_dateofoperationupper DATE,
                             a_decoyname     VARCHAR2,
                             a_phonenumber   NUMBER,
                             a_caseagent     VARCHAR2,
                             a_officersinvolved VARCHAR2,
                             a_district      VARCHAR2,
                             a_agency        VARCHAR2,
                             a_address1line  VARCHAR2,
                             a_licensenumber VARCHAR2)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_dateofoperation IS NULL
       AND a_dateofoperationupper IS NULL
       AND a_decoyname IS NULL
       AND a_phonenumber IS NULL
       AND a_caseagent IS NULL
       AND a_officersinvolved IS NULL
       AND a_district IS NULL
       AND a_agency IS NULL
       AND a_address1line IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_GrantData');
        -- Limit to Shoulder Tap Grant Data
        extension.pkg_cxproceduralsearch.searchbyindex('GrantType',
                                                       'Shoulder Tap',
                                                       NULL);

        IF a_dateofoperation IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateOfOperation',
                a_dateofoperation,
                a_dateofoperationupper);
        END IF;

        IF a_decoyname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('DecoyName',
                                                           a_decoyname,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_phonenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('PhoneNumber',
                                                           a_phonenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_caseagent IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('CaseAgent',
                                                           a_caseagent,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_officersinvolved IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'OfficersInvolved',
                '%' || a_officersinvolved || '%',
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DistrictOfficePDAddress',
                a_district,
                NULL,
                TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Agency',
                'AgencyName',
                a_agency,
                NULL,
                TRUE);
        END IF;

        IF a_address1line IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'Address1Line',
                a_address1line,
                NULL,
                TRUE);
        END IF;

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'LicenseNumber',
                a_licensenumber,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('Submitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findshouldertap;

    PROCEDURE findminordecoy(a_dateofoperation            DATE,
                             a_dateofoperationupper       DATE,
                             a_decoyname                  VARCHAR2,
                             a_phonenumber                NUMBER,
                             a_caseagent                  VARCHAR2,
                             a_district                   VARCHAR2,
                             a_agency                     VARCHAR2,
                             a_officersinvolved           VARCHAR2,
                             a_address1line               VARCHAR2,
                             a_licensenumber              VARCHAR2,
                             a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_dateofoperation IS NULL
       AND a_dateofoperationupper IS NULL
       AND a_decoyname IS NULL
       AND a_phonenumber IS NULL
       AND a_caseagent IS NULL
       AND a_officersinvolved IS NULL
       AND a_district IS NULL
       AND a_agency IS NULL
       AND a_licensenumber IS NULL
       AND a_address1line IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_GrantData');
        -- Limit to Minor Decoy Grant Data
        extension.pkg_cxproceduralsearch.searchbyindex('GrantType',
                                                       'Minor Decoy',
                                                       NULL);

        IF a_dateofoperation IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateOfOperation',
                a_dateofoperation,
                a_dateofoperationupper);
        END IF;

        IF a_decoyname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('DecoyName',
                                                           a_decoyname,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_phonenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('PhoneNumber',
                                                           a_phonenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_caseagent IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('CaseAgent',
                                                           a_caseagent,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_officersinvolved IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'OfficersInvolved',
                '%' || a_officersinvolved,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DistrictOfficePDAddress',
                a_district,
                NULL,
                TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Agency',
                'AgencyName',
                a_agency,
                NULL,
                TRUE);
        END IF;

        IF a_address1line IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'Address1Line',
                a_address1line,
                NULL,
                TRUE);
        END IF;

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'LicenseNumber',
                a_licensenumber,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('Submitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findminordecoy;

    FUNCTION findminordecoy(a_dateofoperation DATE,
                            a_dateofoperationupper DATE,
                            a_decoyname     VARCHAR2,
                            a_phonenumber   NUMBER,
                            a_caseagent     VARCHAR2,
                            a_district      VARCHAR2,
                            a_agency        VARCHAR2,
                            a_officersinvolved VARCHAR2,
                            a_address1line  VARCHAR2,
                            a_licensenumber VARCHAR2)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_dateofoperation IS NULL
       AND a_dateofoperationupper IS NULL
       AND a_decoyname IS NULL
       AND a_phonenumber IS NULL
       AND a_caseagent IS NULL
       AND a_officersinvolved IS NULL
       AND a_district IS NULL
       AND a_agency IS NULL
       AND a_licensenumber IS NULL
       AND a_address1line IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_GrantData');
        -- Limit to Minor Decoy Grant Data
        extension.pkg_cxproceduralsearch.searchbyindex('GrantType',
                                                       'Minor Decoy',
                                                       NULL);

        IF a_dateofoperation IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DateOfOperation',
                a_dateofoperation,
                a_dateofoperationupper);
        END IF;

        IF a_decoyname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('DecoyName',
                                                           a_decoyname,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_phonenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('PhoneNumber',
                                                           a_phonenumber,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_caseagent IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('CaseAgent',
                                                           a_caseagent,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_officersinvolved IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'OfficersInvolved',
                '%' || a_officersinvolved,
                NULL,
                TRUE);
        END IF;

        IF a_district IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'DistrictOfficePDAddress',
                a_district,
                NULL,
                TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Agency',
                'AgencyName',
                a_agency,
                NULL,
                TRUE);
        END IF;

        IF a_address1line IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'Address1Line',
                a_address1line,
                NULL,
                TRUE);
        END IF;

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'LicenseTracker',
                'LicenseNumber',
                a_licensenumber,
                NULL,
                TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('Submitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findminordecoy;

    PROCEDURE findtrapdoor(a_caseagent                  VARCHAR2,
                           a_eventdate                  DATE,
                           a_eventdateupper             DATE,
                           a_specialevent               VARCHAR2,
                           a_eventname                  VARCHAR2,
                           a_agency                     VARCHAR2,
                           a_othertypes                 VARCHAR2,
                           a_state                      VARCHAR2,
                           a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_caseagent IS NULL
       AND a_eventdate IS NULL
       AND a_eventdateupper IS NULL
       AND a_eventname IS NULL
       AND a_agency IS NULL
       AND a_state IS NULL
       AND a_othertypes IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_GrantData');
        -- Limit to Trapdoor Grant Data
        extension.pkg_cxproceduralsearch.searchbyindex('GrantType',
                                                       'Trapdoor',
                                                       NULL);

        IF a_caseagent IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('CaseAgent',
                                                           a_caseagent,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_eventdate IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('DateOfOperation',
                                                           a_eventdate,
                                                           a_eventdateupper);
        END IF;

        IF a_specialevent = 'Y' THEN
            extension.pkg_cxproceduralsearch.filterobjects('SpecialEvent',
                                                           a_specialevent,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_eventname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('EventName',
                                                           a_eventname,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_othertypes IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'OtherTypesOfIDsSeized',
                a_othertypes,
                NULL,
                TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Agency',
                'AgencyName',
                a_agency,
                NULL,
                TRUE);
        END IF;

        IF a_state IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('State',
                                                                  'State',
                                                                  a_state,
                                                                  NULL,
                                                                  FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('Submitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findtrapdoor;

    FUNCTION findtrapdoor(a_caseagent     VARCHAR2,
                          a_eventdate     DATE,
                          a_eventdateupper DATE,
                          a_specialevent  VARCHAR2,
                          a_eventname     VARCHAR2,
                          a_agency        VARCHAR2,
                          a_othertypes    VARCHAR2,
                          a_state         VARCHAR2)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_caseagent IS NULL
       AND a_eventdate IS NULL
       AND a_eventdateupper IS NULL
       AND a_eventname IS NULL
       AND a_agency IS NULL
       AND a_state IS NULL
       AND a_othertypes IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('o_TL_GrantData');
        -- Limit to Trapdoor Grant Data
        extension.pkg_cxproceduralsearch.searchbyindex('GrantType',
                                                       'Trapdoor',
                                                       NULL);

        IF a_caseagent IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('CaseAgent',
                                                           a_caseagent,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_eventdate IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('DateOfOperation',
                                                           a_eventdate,
                                                           a_eventdateupper);
        END IF;

        IF a_specialevent = 'Y' THEN
            extension.pkg_cxproceduralsearch.filterobjects('SpecialEvent',
                                                           a_specialevent,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_eventname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('EventName',
                                                           a_eventname,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_othertypes IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'OtherTypesOfIDsSeized',
                a_othertypes,
                NULL,
                TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Agency',
                'AgencyName',
                a_agency,
                NULL,
                TRUE);
        END IF;

        IF a_state IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('State',
                                                                  'State',
                                                                  a_state,
                                                                  NULL,
                                                                  FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('Submitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findtrapdoor;

    PROCEDURE findovertime(a_agentname                  VARCHAR2,
                           a_granttype                  VARCHAR2,
                           a_month                      VARCHAR2,
                           a_year                       NUMBER,
                           a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_agentname IS NULL
       AND a_granttype IS NULL
       AND a_month IS NULL
       AND a_year IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch(
            'o_TL_OvertimeRecord');

        IF a_agentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_AgentName',
                                                           a_agentname,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_granttype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_GrantType',
                                                           a_granttype,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_month IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Month',
                                                           a_month,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_year IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Year',
                                                           a_year,
                                                           NULL,
                                                           FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        a_objects             := t_unfilteredobjects;
    END findovertime;

    FUNCTION findovertime(a_agentname     VARCHAR2,
                          a_granttype     VARCHAR2,
                          a_month         VARCHAR2,
                          a_year          NUMBER)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();

        IF a_agentname IS NULL
       AND a_granttype IS NULL
       AND a_month IS NULL
       AND a_year IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch(
            'o_TL_OvertimeRecord');

        IF a_agentname IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_AgentName',
                                                           a_agentname,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_granttype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_GrantType',
                                                           a_granttype,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_month IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Month',
                                                           a_month,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_year IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Year',
                                                           a_year,
                                                           NULL,
                                                           FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        RETURN t_unfilteredobjects;
    END findovertime;

    PROCEDURE findlicensetracker(
        a_operationdate              DATE,
        a_operationdateupper         DATE,
        a_agency                     VARCHAR2,
        a_licensenumber              VARCHAR2,
        a_granttype                  VARCHAR2,
        a_premaddress                VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist)
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_filteredobjects     api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();
        t_filteredobjects     := api.udt_objectlist();

        IF a_licensenumber IS NULL
       AND a_operationdate IS NULL
       AND a_operationdateupper IS NULL
       AND a_agency IS NULL
       AND a_granttype IS NULL
       AND a_premaddress IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;



        extension.pkg_cxproceduralsearch.initializesearch(
            'o_TL_LicenseTracker');

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('LicenseNumber',
                                                           a_licensenumber,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_premaddress IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Address1Line',
                                                           a_premaddress,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_AgencyList',
                                                           '%' || a_agency,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_granttype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'GrantData',
                'GrantType',
                a_granttype,
                NULL,
                FALSE);
        END IF;

        IF a_operationdate IS NOT NULL
        OR a_operationdateupper IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'GrantData',
                'DateOfOperation',
                a_operationdate,
                a_operationdateupper);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('DataSubmitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        SELECT api.udt_object(x.objectid)
          BULK COLLECT INTO t_filteredobjects
          FROM TABLE(t_unfilteredobjects)  x
               JOIN query.r_licensetrackergrantdata ltgd
                   ON ltgd.licensetrackerobjectid = x.objectid;

        a_objects             := t_filteredobjects;
    END findlicensetracker;

    FUNCTION findlicensetracker(a_operationdate DATE,
                                a_operationdateupper DATE,
                                a_agency        VARCHAR2,
                                a_licensenumber VARCHAR2,
                                a_granttype     VARCHAR2,
                                a_premaddress   VARCHAR2)
        RETURN api.udt_objectlist
    IS
        t_unfilteredobjects   api.udt_objectlist;
        t_filteredobjects     api.udt_objectlist;
    BEGIN
        t_unfilteredobjects   := api.udt_objectlist();
        t_filteredobjects     := api.udt_objectlist();

        IF a_licensenumber IS NULL
       AND a_operationdate IS NULL
       AND a_operationdateupper IS NULL
       AND a_agency IS NULL
       AND a_granttype IS NULL
       AND a_premaddress IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No search criteria provided. Please provide search criteria and try again.');
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch(
            'o_TL_LicenseTracker');

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('LicenseNumber',
                                                           a_licensenumber,
                                                           NULL,
                                                           FALSE);
        END IF;

        IF a_premaddress IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('Address1Line',
                                                           a_premaddress,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_agency IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('dup_AgencyList',
                                                           '%' || a_agency,
                                                           NULL,
                                                           TRUE);
        END IF;

        IF a_granttype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'GrantData',
                'GrantType',
                a_granttype,
                NULL,
                FALSE);
        END IF;

        IF a_operationdate IS NOT NULL
        OR a_operationdateupper IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'GrantData',
                'DateOfOperation',
                a_operationdate,
                a_operationdateupper);
        END IF;

        extension.pkg_cxproceduralsearch.filterobjects('DataSubmitted',
                                                       'Y',
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_unfilteredobjects,
                                                       'and',
                                                       'none');

        SELECT api.udt_object(x.objectid)
          BULK COLLECT INTO t_filteredobjects
          FROM TABLE(t_unfilteredobjects)  x
               JOIN query.r_licensetrackergrantdata ltgd
                   ON ltgd.licensetrackerobjectid = x.objectid;

        RETURN t_filteredobjects;
    END findlicensetracker;
END pkg_tlsearch;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_TLSEARCH TO POSSEEXTENSIONS;
