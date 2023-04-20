CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_STATUSCHANGE"
IS
    -- **************************************************************************
    -- File:        PKG_STATUSCHANGE.PKS
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

    /*------------------------------------------------------------------------*
     * Types declaration
     *------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    SUBTYPE udt_stringlist IS api.pkg_definition.udt_stringlist;

    /*------------------------
    --
    */
    ------------------------

    PROCEDURE ltstatuschange(a_relationshipid udt_id,
                             a_asofdate      DATE,
                             a_status        VARCHAR2,
                             a_statusdate    DATE);

    /*---------------------------------------------------------
    --  Log Status Changes of Primary License Type Objects
    */
    ---------------------------------------------------------

    PROCEDURE pltostatuschange(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_status        VARCHAR2,
                               a_statusdate    DATE);

    /*---------------------------------------------------------
    --  Log Status Changes of Secondary License Type Rels
    */
    ---------------------------------------------------------

    PROCEDURE sltrstatuschange(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_status        VARCHAR2,
                               a_statusdate    DATE);

    /*---------------------------------------------------------
     --Set Effective Date on Secondary License Types
    */
    ---------------------------------------------------------

    PROCEDURE slteffectivedate(a_objectid udt_id, a_asofdate DATE);
END pkg_statuschange;
/
