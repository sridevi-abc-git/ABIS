CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_LICENSE"
IS
    -- **************************************************************************
    -- File:        PKG_LICENSE.pks
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
    -- 12/10/2023 PK          Created PROCEDURE generateCreateCatererEventAuthextfilenum
    -- 12/10/2023 PK          Created PROCEDURE copycreatecaterertoIssuecaterer
   
    -- **************************************************************************

    /*------------------------------------------------------------------------*
    * Types declaration
    *------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*------------------------------------------------------------------------*
     -- ActivatePendingSecondaryLTs()
     -- Upon completion of the Issue License Process
     -- this will activate all Pending secondary license types.
    *------------------------------------------------------------------------*/

    PROCEDURE activatependingsecondarylts(a_processid     udt_id,
                                          a_asofdate      DATE,
                                          a_jobid         udt_id);

    -------------------------------------------------
    -- SetBatchFlagsIssueLicenseType()
    -- Called on the Issue out come of IssueLicenseType
    -------------------------------------------------

    PROCEDURE setbatchflagsissuelicensetype(a_processid     udt_id,
                                            a_asofdate      DATE);

    /*----------------------------------------------------------------------
    -- Create 150 Day Reminder
    ----------------------------------------------------------------------*/
    PROCEDURE create150dayreminder(a_objectid udt_id, a_asofdate DATE);


    /*----------------------------------------------------------------------
    -- Create Manage Priority Application External File Number
    -- Format is CountyCode - YYYY - [00]
    ----------------------------------------------------------------------*/
    PROCEDURE createmanagepriorityappfilenum(a_jobid udt_id, a_asofdate DATE);

    ----------------------------------------------------------------------------------------------------
    --  GenerateAppExternalFileNum() -- PUBLIC
    --  This generates the external file number on the Application Job
    ----------------------------------------------------------------------------------------------------
    PROCEDURE generateappexternalfilenum(a_objectid udt_id, a_asofdate DATE);


    ----------------------------------------------------------------------------------------------------
    --  GenerateAssignLicenseInvExternalFileNum() -- PUBLIC
    --  This generates the external file number on the Assign License Investigation (which is copied to the Conduct).
    ----------------------------------------------------------------------------------------------------
    PROCEDURE generateassigninvextfilenum(a_objectid udt_id, a_asofdate DATE);

    ----------------------------------------------------------------------------------------------------
    --  CopyAssignInvEFNToCondInv() -- PUBLIC
    --  Copies external file number on the Assign License/Admin Investigation process to Conduct License/Admin Investigation process.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE copyassigninvefntocondinv(a_objectid      udt_id,
                                        a_asofdate      DATE,
                                        a_jobid         udt_id);

    ----------------------------------------------------------------------------------------------------
    --  CopyConductInvEFNToCloseInv() -- PUBLIC
    --  Copies external file number on the Conduct License/Admin Investigation process to Close Investigation process.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE copyconductinvefntocloseinv(a_objectid      udt_id,
                                          a_asofdate      DATE,
                                          a_jobid         udt_id);

    ----------------------------------------------------------------------------------------------------
    --  IssueBeerKegTag() -- PUBLIC
    -- Runs on completion of the Issue Beer Keg process. Created the BKT fee, and writes out the tags
    -- to a table for searching.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE issuebeerkegtags(a_objectid udt_id, a_asofdate DATE);

    ----------------------------------------------------------------------------------------------------
    --  ReinstateLicense() -- PUBLIC
    --  Create and completes Reinstate License Types on the related license types.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE reinstatelicense(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_jobid         udt_id,
                               a_overridebalanceowingcheck CHAR);

    -------------------------------------------------
    --  AutoHold
    --  Create a hold related to the application upon completion of the enter application.
    --  The mandatory columns are defaulted but can be changed with the congifuration window.
    -------------------------------------------------

    PROCEDURE autohold(a_objectid      udt_id,
                       a_asofdate      DATE,
                       a_jobid         udt_id,
                       a_holdtype      VARCHAR2,
                       a_holdcomment   VARCHAR2);

    -------------------------------------------------
    -- MasterP12Rel()
    --  This procedure is used as a Procedural Relationship from a P12 License
    -- to the Master P12 License used for a link widget.
    -------------------------------------------------
    PROCEDURE masterp12rel(a_objectid         udt_id,
                           a_endpointid       udt_id,
                           a_relatedobjectids OUT api.udt_objectlist);


    -------------------------------------------------
    --  WithdrawLicenseTypes()
    --  This procedure is called on completion of the Withdraw Application Process and if all
    --  license types are Withdrawn the Application status will be changed to WITHDRAWN.
    -------------------------------------------------

    PROCEDURE withdrawlicensetypes(a_objectid      udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id);

    -------------------------------------------------
    --  ReloadProcessGrids()
    --  Called on removal of the secondary license types this process will reload the
    --  IssueLicense process grid and WithdrawApplication process grid by deleting
    -- incomplete processes and recreating them.
    -------------------------------------------------
    PROCEDURE reloadprocessgrids(a_objectid      udt_id,
                                 a_asofdate      DATE,
                                 a_jobid         udt_id);

    -------------------------------------------------
    --  ProtestantSelection()
    --  Called when the user clicks the Select All or Deselect All links
    --  on the Protestants tab on the Application job. This will get the
    --  Protestants currently on display and flag the Selected For Reporting column.
    -------------------------------------------------
    PROCEDURE protestantselection(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_jobid         NUMBER,
                                  a_lastname      VARCHAR2,
                                  a_firstname     VARCHAR2,
                                  a_addressline1  VARCHAR2,
                                  a_city          VARCHAR2,
                                  a_state         VARCHAR2,
                                  a_zipcode       VARCHAR2,
                                  a_protestantreportingselection VARCHAR2);

    ----------------------------------------------------------------------------------------------------
    -- ProcessAll() -- PUBLIC
    -- Change status of all License Types and Secondaries to the selected Status
    ----------------------------------------------------------------------------------------------------
    PROCEDURE processall(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id);

    ---------------------------------------------------------
    PROCEDURE flaglicenseforprocessing(a_objectid udt_id, a_asofdate DATE);

    ----------------------------------------------------------------------------------------------------
    --  MaintainMasterP12Rels() -- PUBLIC
    --  Create/Remove the Master P12 Relationships on the License JobType
    --  Called from the ThisLicenseIsP12Master detail
    ----------------------------------------------------------------------------------------------------
    PROCEDURE maintainmasterp12rels(a_objectid udt_id, a_asofdate DATE);
    -----------------------------------------------------------------
    --Generate Validation Code in License Job
    --Executed as constructor on License job
    PROCEDURE generatevalidationcode(a_objectid udt_id, a_asofdate DATE);
 ----------------------------------------------------------------------------------------------------
    --  GenerateCreateCatererEventAuthextfilenum() -- PUBLIC
    --  This generates the external file number on the CreatecateretEventAuth process (which is copied to the Issue Caterer auth process).
    ----------------------------------------------------------------------------------------------------   
 PROCEDURE generateCreateCatererEventAuthextfilenum(a_objectid udt_id, a_asofdate DATE);
    
   ----------------------------------------------------------------------------------------------------
    --  copycreatecaterertoIssuecaterer() -- PUBLIC
    --  Copies external file number on the Create Caterer / Event Authorization process to Issue Caterer / Event Authorization process.
    ---------------------------------------------------------------------------------------------------- 
    PROCEDURE copycreatecaterertoIssuecaterer(a_objectid      udt_id,
                                          a_asofdate      DATE,
                                          a_jobid         udt_id);     
  -----------------------------------------------------------------------------------------------------------------------------------------  

   
END pkg_license;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_LICENSE TO BIZMOD_API;

GRANT EXECUTE ON SITESPECIFIC.PKG_LICENSE TO POSSEEXTENSIONS;
