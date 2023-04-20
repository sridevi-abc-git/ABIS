CREATE OR REPLACE PACKAGE ABC.pkg_abcreports_61adhoc
AS
    -- **************************************************************************
    -- File:        PKG_ABCREPORTS_61ADHOC.PKS
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
    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    PROCEDURE abc61assignmentoverview(a_objectid udt_id);

    PROCEDURE getofficeobjectid(a_districtoffice   VARCHAR2,
                                a_officecode   OUT VARCHAR2,
                                a_office       OUT VARCHAR2,
                                a_objectid     OUT udt_id);

    PROCEDURE getcountycode(a_county IN OUT VARCHAR2);

    FUNCTION enfcrewassignment(a_objectid udt_id)
        RETURN VARCHAR2;

    FUNCTION liccrewassignment(a_objectid udt_id)
        RETURN VARCHAR2;

    PROCEDURE get61enfassignments(a_objectid      udt_id,
                                  a_investigationnumber VARCHAR2,
                                  a_investigationtype VARCHAR2,
                                  a_investigator  VARCHAR2,
                                  a_includecrewassignments CHAR,
                                  a_firstvisitdate DATE,
                                  a_activeonly    CHAR,
                                  a_licensenumber VARCHAR2,
                                  a_departmentpriority CHAR,
                                  a_createddatefrom DATE,
                                  a_createddateto DATE,
                                  a_completeddatefrom DATE,
                                  a_completeddateto DATE,
                                  a_city          VARCHAR2,
                                  a_county        VARCHAR2,
                                  a_officecode    VARCHAR2,
                                  a_userid        udt_id,
                                  a_objectids     api.udt_objectlist);

    PROCEDURE get61licassignments(
        a_objectid      udt_id,
        a_investigationnumber VARCHAR2,
        a_investigationtype VARCHAR2,
        a_investigator  VARCHAR2,
        a_includecrewassignments CHAR,
        a_firstvisitdate DATE,
        a_activeonly    CHAR,
        a_licensenumber VARCHAR2,
        a_departmentpriority CHAR,
        a_createddatefrom DATE,
        a_createddateto DATE,
        a_completeddatefrom DATE,
        a_completeddateto DATE,
        a_city          VARCHAR2,
        a_county        VARCHAR2,
        a_officecode    VARCHAR2,
        a_userid        udt_id,
        a_objectids     api.udt_objectlist DEFAULT api.udt_objectlist());

    PROCEDURE get61admassignments(
        a_objectid      udt_id,
        a_investigationnumber VARCHAR2,
        a_investigationtype VARCHAR2,
        a_investigator  VARCHAR2,
        a_includecrewassignments CHAR,
        a_firstvisitdate DATE,
        a_activeonly    CHAR,
        a_licensenumber VARCHAR2,
        a_departmentpriority CHAR,
        a_createddatefrom DATE,
        a_createddateto DATE,
        a_completeddatefrom DATE,
        a_completeddateto DATE,
        a_city          VARCHAR2,
        a_county        VARCHAR2,
        a_office        VARCHAR2,
        a_userid        udt_id,
        a_objectids     api.udt_objectlist DEFAULT api.udt_objectlist());

    FUNCTION getliccompleteddate(a_objectid udt_id)
        RETURN DATE;

    FUNCTION getenfcompleteddate(a_objectid udt_id)
        RETURN DATE;
END pkg_abcreports_61adhoc;
/


GRANT EXECUTE, DEBUG ON ABC.PKG_ABCREPORTS_61ADHOC TO KAURP;

GRANT EXECUTE ON ABC.PKG_ABCREPORTS_61ADHOC TO POSSEEXTENSIONS;
