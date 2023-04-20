CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_tlsearch
IS
    -- **************************************************************************
    -- File:        PKG_TLSEARCH.PKS
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
                            a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findleadclass(a_district                   VARCHAR2,
                            a_trainingdate               DATE,
                            a_objects         OUT NOCOPY api.udt_objectlist);

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
        RETURN api.udt_objectlist;

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
                            a_objects         OUT NOCOPY api.udt_objectlist);

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
        RETURN api.udt_objectlist;

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
        a_objects         OUT NOCOPY api.udt_objectlist);

    FUNCTION findtracecheckpoint(a_agentname     VARCHAR2,
                                 a_district      VARCHAR2,
                                 a_county        VARCHAR2,
                                 a_city          VARCHAR2,
                                 a_location      VARCHAR2,
                                 a_agencyhostingcheckpoint VARCHAR2,
                                 a_checkpointdate DATE,
                                 a_checkpointdateupper DATE,
                                 a_tracetype     VARCHAR2)
        RETURN api.udt_objectlist;


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
        a_objects         OUT NOCOPY api.udt_objectlist);

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
        RETURN api.udt_objectlist;

    PROCEDURE findimpact(a_dateofoperation            DATE,
                         a_licensenumber              VARCHAR2,
                         a_address1line               VARCHAR2,
                         a_dateofoperationupper       DATE,
                         a_district                   VARCHAR2,
                         a_agency                     VARCHAR2,
                         a_objects         OUT NOCOPY api.udt_objectlist);

    FUNCTION findimpact(a_dateofoperation DATE,
                        a_dateofoperationupper DATE,
                        a_licensenumber VARCHAR2,
                        a_address1line  VARCHAR2,
                        a_district      VARCHAR2,
                        a_agency        VARCHAR2)
        RETURN api.udt_objectlist;

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
        a_objects         OUT NOCOPY api.udt_objectlist);

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
        RETURN api.udt_objectlist;

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
                             a_objects         OUT NOCOPY api.udt_objectlist);

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
        RETURN api.udt_objectlist;

    PROCEDURE findtrapdoor(a_caseagent                  VARCHAR2,
                           a_eventdate                  DATE,
                           a_eventdateupper             DATE,
                           a_specialevent               VARCHAR2,
                           a_eventname                  VARCHAR2,
                           a_agency                     VARCHAR2,
                           a_othertypes                 VARCHAR2,
                           a_state                      VARCHAR2,
                           a_objects         OUT NOCOPY api.udt_objectlist);

    FUNCTION findtrapdoor(a_caseagent     VARCHAR2,
                          a_eventdate     DATE,
                          a_eventdateupper DATE,
                          a_specialevent  VARCHAR2,
                          a_eventname     VARCHAR2,
                          a_agency        VARCHAR2,
                          a_othertypes    VARCHAR2,
                          a_state         VARCHAR2)
        RETURN api.udt_objectlist;

    PROCEDURE findovertime(a_agentname                  VARCHAR2,
                           a_granttype                  VARCHAR2,
                           a_month                      VARCHAR2,
                           a_year                       NUMBER,
                           a_objects         OUT NOCOPY api.udt_objectlist);

    FUNCTION findovertime(a_agentname     VARCHAR2,
                          a_granttype     VARCHAR2,
                          a_month         VARCHAR2,
                          a_year          NUMBER)
        RETURN api.udt_objectlist;

    PROCEDURE findlicensetracker(
        a_operationdate              DATE,
        a_operationdateupper         DATE,
        a_agency                     VARCHAR2,
        a_licensenumber              VARCHAR2,
        a_granttype                  VARCHAR2,
        a_premaddress                VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    FUNCTION findlicensetracker(a_operationdate DATE,
                                a_operationdateupper DATE,
                                a_agency        VARCHAR2,
                                a_licensenumber VARCHAR2,
                                a_granttype     VARCHAR2,
                                a_premaddress   VARCHAR2)
        RETURN api.udt_objectlist;
END pkg_tlsearch;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_TLSEARCH TO POSSEEXTENSIONS;
