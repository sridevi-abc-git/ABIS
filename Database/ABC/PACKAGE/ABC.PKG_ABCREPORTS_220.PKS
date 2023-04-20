CREATE OR REPLACE PACKAGE ABC.pkg_abcreports_220
AS
    -- **************************************************************************
    -- File:        PKG_ABCREPORTS_220.PKS
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

    PROCEDURE abc220assignmentoverview(a_objectid udt_id);

    PROCEDURE getoffice(a_districtoffice   VARCHAR2,
                        a_officename   OUT VARCHAR2,
                        a_office       OUT VARCHAR2);

    FUNCTION get220result(a_objectid udt_id)
        RETURN api.processes.outcome%TYPE;

    PROCEDURE get220appjoblist(a_createddatefrom  DATE,
                               a_createddateto    DATE,
                               a_districtoffice   VARCHAR2,
                               a_licensenumber    VARCHAR2,
                               a_licensee         VARCHAR2,
                               a_appjoblist   OUT api.udt_objectlist,
                               a_projoblist   OUT api.udt_objectlist --xxxxxxxxx
                                                                    );

    PROCEDURE getdistrevlist(a_completeddatefrom DATE,
                             a_completeddateto  DATE,
                             a_distrevlist  OUT api.udt_objectlist);

    PROCEDURE getactivelist(a_appjobids IN OUT api.udt_objectlist);

    PROCEDURE getuserassignments(a_investigatorlr   VARCHAR2,
                                 a_districtofficename VARCHAR2,
                                 a_districtoffice   VARCHAR2,
                                 a_appjoblist   OUT api.udt_objectlist);

    PROCEDURE getassignedemp(a_objectid udt_id, a_emp OUT VARCHAR2);

    FUNCTION getthrudate(a_objectid udt_id)
        RETURN DATE;
END pkg_abcreports_220;
/


GRANT EXECUTE ON ABC.PKG_ABCREPORTS_220 TO POSSEEXTENSIONS;
