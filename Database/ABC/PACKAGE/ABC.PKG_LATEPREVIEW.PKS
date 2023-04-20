CREATE OR REPLACE PACKAGE ABC."PKG_LATEPREVIEW"
AS
    -- **************************************************************************
    -- File:        PKG_LATEPREVIEW.PKS
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
    -------------------------------------
    --        SPECS Types
    -------------------------------------
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    -------------------------------------
    PROCEDURE late2ndnotice_amtrpt_pkg(a_jobid udt_id);

    PROCEDURE listlatelicensesrpt_pkg(a_jobid udt_id);

    PROCEDURE lppart1_licwexpdt_amtrpt_pkg(a_jobid udt_id);

    PROCEDURE lppart2_r91latnotfor_rpt_pkg(a_jobid udt_id);
END pkg_latepreview;
/


GRANT EXECUTE ON ABC.PKG_LATEPREVIEW TO POSSEEXTENSIONS;
