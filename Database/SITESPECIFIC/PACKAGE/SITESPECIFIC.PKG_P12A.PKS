CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_p12a
IS
    -- **************************************************************************
    -- File:        PKG_P12A.PKS
    -- Author:      KEATON
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Purpose : A container for all of the P12A code
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 05/15/2012             Created
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;


    ---------------------------------------------------------------------------------------------------
    --   * P12MasterLELookup() -- PUBLIC
    -- Finds the ConvertLEToP12 process's (License) job's Licensees and/or P12Licensee objectids.
    -- Used for P12Master lookup dropdown) on the ConvertLEToP12 process.
    ---------------------------------------------------------------------------------------------------
    PROCEDURE p12amasterlelookup(a_object           udt_id,
                                 a_relationshipdef  udt_id,
                                 a_endpoint         udt_endpoint,
                                 a_searchstring     VARCHAR2,
                                 a_relatedobjectids OUT udt_objectlist);

    PROCEDURE p12arecurmasterlelookup(
        a_object              udt_id,
        a_relatedobjectids IN OUT udt_objectlist);

    PROCEDURE p12alelookup(a_object           udt_id,
                           a_relationshipdef  udt_id,
                           a_endpoint         udt_endpoint,
                           a_searchstring     VARCHAR2,
                           a_relatedobjectids OUT udt_objectlist);

    PROCEDURE p12areclelookup(a_object              udt_id,
                              a_relatedobjectids IN OUT udt_objectlist);

    PROCEDURE p12amasterchangelookup(a_object           udt_id,
                                     a_relationshipdef  udt_id,
                                     a_endpoint         udt_endpoint,
                                     a_searchstring     VARCHAR2,
                                     a_relatedobjectids OUT udt_objectlist);


    ---------------------------------------------------------------------------------------------------
    --   * RelateLEtoProcessForP12A() -- PUBLIC
    -- Called by Constructor of the Master Legal Entity relationship of process p_convertLEtoP12A.
    -- Referencing the Master Legal Entity, find all other LEs for that same Company or Person
    -- which are Licensees, and relate them to process p_convertLEtoP12A,
    -- as part of converting the Legal Enties to P12A.
    ---------------------------------------------------------------------------------------------------

    PROCEDURE relateletoprocessforp12a(         -- Called by p_convertLEtoP12A
                                       a_relationshipid udt_id,
                                       a_asofdate      DATE);

    ---------------------------------------------------------------------------------------------------
    --   * ConvertLEToP12A() -- PUBLIC
    -- Called at completion of process p_convertLEtoP12A.
    -- Sets the P12A status on the LE to 'Y' and changes the related Les to P12As
    -- Records a Log of the P12As to the log table
    ---------------------------------------------------------------------------------------------------
    PROCEDURE convertletop12a(a_processobjectid udt_id, a_asofdate DATE);

    ---------------------------------------------------------------------------------------------------
    --   * ConvertP12AToLE() -- PUBLIC
    -- Called at completion of process p_convertP12AtoLE.
    -- Sets P12A status on P12 Master Legal Entity.
    -- For Each Legal Entity candidate related to process update the P12A status to N
    -- and remove the P12A from the log table
    ---------------------------------------------------------------------------------------------------
    PROCEDURE convertp12atole(a_processobjectid udt_id, a_asofdate DATE);

    ---------------------------------------------------------------------------------------------------
    --   * MaintainP12A() -- PUBLIC
    -- Called at change of Master P12A to maintain all P12A children
    ---------------------------------------------------------------------------------------------------
    PROCEDURE maintainp12a(a_objectid udt_id, a_asofdate DATE);

    PROCEDURE p12adeletecleanup(a_objectid udt_id, a_asofdate DATE);


    PROCEDURE changep12amasterlicense(a_objectid udt_id, a_asofdate DATE);
    
    /*----------------------------------------------------------
     * UpdateP12AMasterLicense()
      * Called from the p12 conversion procedures
      * 
      * When the p12a master legal entity is replaced on the license:
      * 1. Update the p12aLog records
      * 2. Update the p12aMasterLEId on all related p12a Hierarchies
     *---------------------------------------------------------*/
    Procedure UpdateP12AMasterLE (a_p12aMasterLEId  udt_id,
                                  a_AsOfDate   date) ;      
END pkg_p12a;

/
