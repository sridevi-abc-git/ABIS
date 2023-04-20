CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_ENFORCEMENT"
IS
    -- **************************************************************************
    -- File:        PKG_ENFORCEMENT.pks
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

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    ----------------------------------------------------------------------------------------------------
    --  CreateAccusation() -- PUBLIC
    --  Used by Raise Accusation outcome of the Close Investigation process on the Investigation job.
    --  Create Accusation Job, relate Investigation, Office, and Violations to Accusation.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createaccusation(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------
    Create Accusation File Number
    ---------------------------------------------------*/
    PROCEDURE createaccusationfilenumber(a_objectid      udt_id,
                                         a_asofdate      DATE,
                                         a_jobid         udt_id);

    /*---------------------------------------------------
    Create Application Reg. Number
    ---------------------------------------------------*/
    PROCEDURE createapplicationregnumber(a_objectid      udt_id,
                                         a_asofdate      DATE,
                                         a_jobid         udt_id);

    /*---------------------------------------------------
    Create Application Reg. Number
    ---------------------------------------------------*/
    PROCEDURE createregprotestregnumber(a_objectid      udt_id,
                                        a_asofdate      DATE,
                                        a_jobid         udt_id);

    /*---------------------------------------------------
    Create Reg Denial Hearing Reg. Number
    ---------------------------------------------------*/
    PROCEDURE createdenialhearingregnumber(a_objectid      udt_id,
                                           a_asofdate      DATE);

    ---------------------------------------------------------------------------
    -- ChooseInvestigator() -- PUBLIC
    -- Used by the Application and Investigation jobs.
    -- Provides a list of Investigators for an Office, either LR or Enforcement,
    -- depending on which process calls the procedure.
    -- Called from p_AssignInvestigation, p_AssignAppInvestigation,
    -- p_IssueTemporaryPermit, p_IssueInterimRetailPermit
    ---------------------------------------------------------------------------
    PROCEDURE chooseinvestigator(a_object           udt_id,
                                 a_relationshipdef  udt_id,
                                 a_endpoint         udt_endpoint,
                                 a_searchstring     VARCHAR2,
                                 a_objects      OUT udt_objectlist);

    ---------------------------------------------------------------------------
    -- AssignConductInv() -- PUBLIC
    -- Used by the Application and Investigation jobs to assign
    -- Investigator(s) to a Conduct Investigation process.
    -- Called from outcome of p_AssignInvestigation, p_AssignAppInvestigation.
    -- Assigns to p_ConductEnforcementInv or p_ConductAppInvestigation.
    ---------------------------------------------------------------------------
    PROCEDURE assignconductinv(a_object        udt_id,
                               a_asofdate      DATE,
                               a_jobid         udt_id);

    ---------------------------------------------------------------------------
    -- AssignClose() -- PUBLIC
    -- Used by the Application, License and Investigation jobs to assign
    -- the Supervisor to a Close Investigation or District Application Review processes.
    ---------------------------------------------------------------------------
    PROCEDURE assignclose(a_object udt_id, a_asofdate DATE);

    /*--------------------------------------
     This relationship gets the Prior Accusations from a License
    */
    --------------------------------------

    PROCEDURE prioraccusations(a_objectid         udt_id,
                               a_endpointid       udt_id,
                               a_relatedobjectids OUT api.udt_objectlist);

    /*--------------------------------------
       This is supposed to Create a Hold with Hold object of type "H  Protest" placed by the signed
       on user and relate that Hold object to the Register Protest process and the Application Job.
    */
    --------------------------------------

    PROCEDURE newhlhold(a_objectid      udt_id,
                        a_asofdate      DATE,
                        a_jobid         udt_id,
                        a_lastupdatebyusername VARCHAR2);

    /*--------------------------------------
       When the Record Director Decision process is completed this will enters the Current Date
       into any null Hold Released fields on any Hold objects that are attached to any completed Register Protest
       processes on the Application job.
    */
    --------------------------------------

    PROCEDURE releasehlhold(a_objectid      udt_id,
                            a_asofdate      DATE,
                            a_jobid         udt_id,
                            a_currentdate   DATE);

    ----------------------------------------------------------------------------------------------------
    --  SuspendOrRevokeLT() -- PUBLIC
    --   Suspend or Revoke LTs and SLTs for an Accusation
    ----------------------------------------------------------------------------------------------------
    PROCEDURE suspendorrevokelt(a_processid     udt_id,
                                a_asofdate      DATE,
                                a_jobid         udt_id,
                                a_outcome       VARCHAR2);

    ----------------------------------------------------------------------------------------------------
    --  ActivateSuspendedLicense() -- PUBLIC
    --  On completion of the Close Out Penalty , this will check the related License to see if it was suspended
    --  and it is was create and complete the Activate License process.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE activatesuspendedlicense(a_processid     udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id);

    ----------------------------------------------------------------------------------------------------
    --  SearchForExpiredSuspensions() -- PUBLIC
    --  This procedure looks at the Post Suspension/Revocation processes and check if the Calculated End Date is
    --  less then the current date and greater then the last time this was run and then it will also check to see
    --  if there is a Close Out Penalty process. If there isn't, and the date is within the range, this procedure
    --  create the Close Out Penalty process.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE searchforexpiredsuspensions;

    ---------------------------------------------------------------------------------------------------------------------------
    -- CreateInvFromPrepHearing() - PUBLIC
    -- This creates the Investigation job, Conduct Enforcement Investigation process from the Prep Hearing Memo/Serve Supoenas
    -- process on the Accusation job.
    ---------------------------------------------------------------------------------------------------------------------------
    PROCEDURE createinvfromprephearing(a_objectid      udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id);

    ---------------------------------------------------------------------------------------------------------------------------
    -- CreateInvFromPostSuspRev() - PUBLIC
    -- This creates the Investigation job, Assign Enforcement Investigation process from the Post Suspension/Revocation
    -- process on the Accusation job.
    ---------------------------------------------------------------------------------------------------------------------------
    PROCEDURE createinvfrompostsusprev(a_objectid      udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id);

    ---------------------------------------------------------------------------------------------------------------------------
    -- CreateInvFromProcessPOIC() - PUBLIC
    -- This creates the Investigation job, Assign Enforcement Investigation process from the Process POIC
    -- process on the Accusation job.
    ---------------------------------------------------------------------------------------------------------------------------
    PROCEDURE createinvfromprocesspoic(a_objectid      udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id);

    /*--------------------------------------------------
    --  ValidateAccRel() - PUBLIC
    --  This runs on constructor of r_CreatedByInvestAccusation
    --  and validates that the Accusation is related to the License
    --  in the Investigation.
    */
    --------------------------------------------------

    PROCEDURE validateaccrel(a_objectid udt_id, a_asofdate DATE);
END pkg_enforcement;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_ENFORCEMENT TO POSSEEXTENSIONS;
