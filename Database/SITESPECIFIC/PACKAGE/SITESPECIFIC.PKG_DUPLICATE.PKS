CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_duplicate
IS
    -- **************************************************************************
    -- File:        PKG_DUPLICATE.pks
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

    /*------------------------------------------------------------------------*
     * Types declaration
     *------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    ---------------------------------------------------------
    --  CreateDuplicateRows() -- PUBLIC
    --  This procedures runs on Column change of the New Count column and creates the duplicate rows.
    ---------------------------------------------------------
    PROCEDURE createduplicaterows(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_newcount      NUMBER);

    /*-------------------------------------------------------------------------------
    * Procedure CreateDuplicate()  Used on creation of o_Duplicate.
    *-----------------------------------------------------------------------------*/

    PROCEDURE createduplicate(a_objectid     IN OUT NUMBER,
                              a_relationshipid      NUMBER,
                              a_licensetypejobid    NUMBER,
                              a_licensetypecategoryobjectid NUMBER,
                              a_description         VARCHAR2,
                              a_readytoissuedate    DATE,
                              a_print               VARCHAR2 DEFAULT 'N',
                              a_issuedate           DATE,
                              a_typeofissuance      VARCHAR2,
                              a_primarylicensetypeobjectid NUMBER);

    /*-------------------------------------------------------------------------------
    * Procedure ModifyDuplicate()  Used on modification of o_Duplicate.
    *-----------------------------------------------------------------------------*/

    PROCEDURE modifyduplicate(a_objectid     IN OUT NUMBER,
                              a_relationshipid      NUMBER,
                              a_licensetypejobid    NUMBER,
                              a_licensetypecategoryobjectid NUMBER,
                              a_description         VARCHAR2,
                              a_readytoissuedate    DATE,
                              a_print               VARCHAR2 DEFAULT 'N',
                              a_issuedate           DATE,
                              a_typeofissuance      VARCHAR2,
                              a_primarylicensetypeobjectid NUMBER);

    /*-------------------------------------------------------------------------------
    * Procedure CascadeDuplicateDelete() used on destructor of the relationships to remove externally related duplicate objects.
    *------------------------------------------------------------------------------*/

    PROCEDURE cascadeduplicatedelete(a_objectid udt_id, a_asofdate DATE);
END pkg_duplicate;
/
