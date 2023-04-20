CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_posseprofiler
AS
    -- **************************************************************************
    -- File:        PKG_POSSEPROFILER.PKS
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

    ----------------------------------------------------------------------------
    -- Types
    ----------------------------------------------------------------------------
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    ----------------------------------------------------------------------------
    -- ProfileColumns()
    -- Performs 10 retrievals of every column and stores how long it took
    -- into the PosseProfilerResults table.
    ----------------------------------------------------------------------------
    PROCEDURE profilecolumns(a_maxrows       PLS_INTEGER DEFAULT 10,
                             a_continue      BOOLEAN DEFAULT TRUE);
END pkg_posseprofiler;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_POSSEPROFILER TO POSSESYS;
