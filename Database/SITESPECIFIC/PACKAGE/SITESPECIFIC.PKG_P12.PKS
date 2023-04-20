CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_p12
IS
    -- **************************************************************************
    -- File:        PKG_P12.PKS
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

    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;


    ---------------------------------------------------------------------------------------------------
    --   * P12MasterLELookup() -- PUBLIC
    -- Finds the ConvertLEToP12 process's (License) job's Licensees and/or P12Licensee objectids.
    -- Used for P12Master lookup dropdown) on the ConvertLEToP12 process.
    ---------------------------------------------------------------------------------------------------
    PROCEDURE p12masterlelookup(a_object           udt_id,
                                a_relationshipdef  udt_id,
                                a_endpoint         udt_endpoint,
                                a_searchstring     VARCHAR2,
                                a_relatedobjectids OUT udt_objectlist);

    ---------------------------------------------------------------------------------------------------
    --   * RelateLEtoProcessForP12() -- PUBLIC
    -- Called by Constructor of the Master Legal Entity relationship of process p_convertLEtoP12.
    -- Referencing the Master Legal Entity, find all other LEs for that same Company or Person
    -- which are Licensees, and relate them to process p_convertLEtoP12,
    -- as part of converting the Legal Enties to P12.
    ---------------------------------------------------------------------------------------------------

    PROCEDURE relateletoprocessforp12(           -- Called by p_convertLEtoP12
                                      a_relationshipid udt_id,
                                      a_asofdate      DATE);

    /*---------------------------------------------------------------------------
     * ChangeP12Address() - PUBLIC
     *  Used on completion of the p_ChangeP12MailingAddress process to change the
     *  mailing address on the License job.
     *-------------------------------------------------------------------------*/
    PROCEDURE changep12address(a_processid udt_id, a_asofdate DATE);

    ---------------------------------------------------------------------------------------------------
    --   * ConvertLEToP12() -- PUBLIC
    -- Called at completion of process p_convertLEtoP12.
    -- Sets P12 status on P12 Master Legal Entity.
    -- Sets P12 Master status on P12 Master License.
    -- For Each Legal Entity candidate related to process, removes existing rel License to LE Licensee
    -- and relate to Master P12 Legal Entity
    ---------------------------------------------------------------------------------------------------
    PROCEDURE convertletop12(a_processobjectid udt_id, a_asofdate DATE);

    ---------------------------------------------------------------------------------------------------
    --   * ConvertP12ToLE() -- PUBLIC
    -- Called at completion of process p_convertP12toLE.
    -- Sets P12 status on P12 Master Legal Entity.
    -- Sets P12 Master status on P12 Master License.
    -- For Each Legal Entity candidate related to process, removes existing rel License to LE Licensee
    -- and relate to Master P12 Legal Entity
    ---------------------------------------------------------------------------------------------------
    PROCEDURE convertp12tole(a_processobjectid udt_id, a_asofdate DATE);

    ---------------------------------------------------------------------------------------------------
    --   * SyncExprDateOnP12() -- PUBLIC
    -- Update the non-seasonal License Types related to the P12 License.
    -- The ExpiringMonth and the ExpiringYear are updated to the values on the Process.
    ---------------------------------------------------------------------------------------------------
    PROCEDURE syncexprdateonp12(a_processobjectid udt_id,
                                a_asofdate      DATE,
                                a_jobid         udt_id,
                                a_expirationmonth VARCHAR2,
                                a_expirationyear INTEGER);

    /*----------------------------------------------------------
     * RemoveMasterP12Error()     --Public
     *---------------------------------------------------------*/

    PROCEDURE removemasterp12error(a_objectid udt_id, a_asofdate DATE);

    /*--------------------
    -- UpdateP12MAFromProcess() - PUBLIC
    -- This procedure is to be run as a deffered procedure on completion of the Change P12 Master License
    -- and Convert LE to P12 processes. This will check the new P12 Master License and make that License's
    -- Mailing Address the address for all the children Licenses. This includes deleting the children
    -- Mailing Addresses if the Master License does not have one.
    */
    --------------------

    PROCEDURE updatep12mafromprocess(a_objectid udt_id, a_asofdate DATE);

    /*********************
    -- RelateP12MailingAddr() - PUBLIC
    -- This is to run on constructor of the License/MailingAddress relationship
    -- and if the License is a P12 Master, it will create/update the Mailing
    -- Address rels on all the other related P12 Licenses/Applications to
    -- match the new Mailing Address rel on the P12 Master License.
    *********************/

    PROCEDURE relatep12mailingaddr(a_objectid udt_id, a_asofdate DATE);

    /*********************
    -- RemoveP12MailingAddr() - PUBLIC
    -- This is to run on constructor of the License/MailingAddress relationship
    -- and if the License is a P12 Master, it will create/update the Mailing
    -- Address rels on all the other related P12 Licenses/Applications to
    -- match the new Mailing Address rel on the P12 Master License.
    *********************/

    PROCEDURE removep12mailingaddr(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * DeleteP12Address() - PUBLIC
     *  Remove a P12 Mailing Address on a given p_ChangeP12MailingAddress process.
     *-------------------------------------------------------------------------*/
    PROCEDURE deletep12address(a_processid udt_id, a_asofdate DATE);

    ---------------------------

    /*---------------------------------------------------------------------------
     * GetP12RelIds() -- PUBLIC
     * Called by the Delete Widget on the Legal Entity Grid. Used to remove the stored relationship
     *-------------------------------------------------------------------------*/

    PROCEDURE getp12relids(a_objectid udt_id, a_asofdate DATE);


    /*---------------------------------------------------------------------------
       * Primary P12 Procedural Lookup for License, Used to Select the Primary
       * P12 Legal Entity
       *-------------------------------------------------------------------------*/

    PROCEDURE lookupprimaryp12lic(a_objectid         udt_id,
                                  a_relationshipdefid udt_id,
                                  a_endpoint         VARCHAR2,
                                  a_searchstring     VARCHAR2,
                                  a_objects      OUT udt_objectlist);

    /*---------------------------------------------------------------------------
       *Primary P12 Procedural Lookup for Application, Used to Select the Primary
       *P12 Legal Entity
       *-------------------------------------------------------------------------*/

    PROCEDURE lookupprimaryp12app(a_objectid         udt_id,
                                  a_relationshipdefid udt_id,
                                  a_endpoint         VARCHAR2,
                                  a_searchstring     VARCHAR2,
                                  a_objects      OUT udt_objectlist);

    /*---------------------------------------------------------------------------
       * LookupDeleteP12Lic Used on the Delete Widget in the Legal Entity Grid to
       * Delete to Correct Relationship
       *-------------------------------------------------------------------------*/

    FUNCTION lookupdeletep12lic(a_licenseobjectid udt_id,
                                a_p12legalentityid udt_id)
        RETURN NUMBER;

    /*---------------------------------------------------------------------------
       * LookupDeleteP12App Used on the Delete Widget in the Legal Entity Grid to
       * Delete to Correct Relationship
       *-------------------------------------------------------------------------*/

    FUNCTION lookupdeletep12app(a_applicationobjectid udt_id,
                                a_p12legalentityid udt_id)
        RETURN NUMBER;

    /*---------------------------------------------------------------------------
       * CreatePrimaryP12IfNewLic Used on the creation of the P12 Rel to License
       * If there is no primary Create and Primary Rel
       * If there is no address and addressid is passed in adds a mailing address
       *-------------------------------------------------------------------------*/

    PROCEDURE createprimaryp12ifnewlic(a_relationshipid udt_id,
                                       a_asofdate      DATE,
                                       a_addressid     NUMBER DEFAULT NULL);

    /*---------------------------------------------------------------------------
       * CreatePrimaryP12IfNewApp Used on the creation of the P12 Rel to Application
       * If there is no primary Create and Primary Rel
       * If there is no address and addressid is passed in adds a mailing address
       *-------------------------------------------------------------------------*/

    PROCEDURE createprimaryp12ifnewapp(a_relationshipid udt_id,
                                       a_asofdate      DATE,
                                       a_addressid     NUMBER DEFAULT NULL);

    /*---------------------------------------------------------------------------
       * RemoveP12App is used on the Remove P12 link to remove the last P12
       * on an Applicaion it also deletes the primary P12 rel to prevent
       * data problems if a P12 is added to the application again
       *-------------------------------------------------------------------------*/

    PROCEDURE removep12app(a_jobid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
       * RemoveP12Lic is used on the Remove P12 link to remove the last P12
       * on a License it also deletes the primary P12 rel to prevent
       * data problems if a P12 is added to the application again
       *-------------------------------------------------------------------------*/

    PROCEDURE removep12lic(a_jobid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
       * DeletePrimaryP12App is used on the Convert P12 to LE process and
       * raises an error if the P12 is a Primary where there is more than one P12
       * present if it is the only P12 the primiary Rel will be deleted and cleaned up
       *-------------------------------------------------------------------------*/
    PROCEDURE deleteprimaryp12app(a_jobid udt_id);

    /*---------------------------------------------------------------------------
       * DeletePrimaryP12Lic is used on the Convert P12 to LE process and
       * raises an error if the P12 is a Primary where there is more than one P12
       * present if it is the only P12 the primiary Rel will be deleted and cleaned up
       *-------------------------------------------------------------------------*/
    PROCEDURE deleteprimaryp12lic(a_jobid udt_id);

    /*---------------------------------------------------------------------------
       * PropogateP12Address is used when changing a primary P12 from code by
       * converting LE to P12 and updates the mailing address correctly
       *-------------------------------------------------------------------------*/

    PROCEDURE propogatep12address(a_endpoint      NUMBER,
                                  a_jobid         NUMBER,
                                  a_addressid     NUMBER);

    /*---------------------------------------------------------------------------
       * UpdateP12AddressLic is used when changing a mailing address on the P12 master
       * To update the children addresses
       *-------------------------------------------------------------------------*/

    PROCEDURE updatep12addresslic(a_relationshipid udt_id, a_asofdate DATE);
END pkg_p12;

/


GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_P12 TO KAURP;

GRANT EXECUTE ON SITESPECIFIC.PKG_P12 TO POSSEEXTENSIONS;

GRANT EXECUTE ON SITESPECIFIC.PKG_P12 TO TOOLBOX;
