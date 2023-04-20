CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_prioritydraw
AS
    -- **************************************************************************
    -- File:        PKG_PRIORITYDRAW.PKS
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

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*---------------------------------------------------------------------------
    * CreateCountyRels()
    *  This procedure finds all of the County objects and relates them to a
    *  Prepare for Priority Applications Job.
    *-------------------------------------------------------------------------*/
    PROCEDURE createcountyrels(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
    * CreateManagePriorityAppSubjobs()
    *  This procedure creates a subjob for each County attached to a
    *  Prepare for Priority Applications job
    *-------------------------------------------------------------------------*/
    PROCEDURE createmanagepriorityappsubjobs(a_objectid      udt_id,
                                             a_asofdate      DATE,
                                             a_jobid         udt_id);

    /**********************************************
    -- RelatePDApplications()
    -- This is run on completion of the Relate PD Applications process on the Manage Priority Applications job. This gets all the PD
    -- Applications from the County related to the Manage job. The procedure gets the Applications related to the County through the
    -- Base File Office relationship.
    **********************************************/
    PROCEDURE relatepdapplications(a_objectid      udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id);

    /**********************************************
     -- RelatePDApplication()
     -- This is run on the creation of the Application to County
     -- relationship to automatically relate the Priority Draw Application
     -- to the Manage Job
     **********************************************/
    PROCEDURE relatepdapplication(a_relationshipid udt_id, a_asofdate DATE);

    --------------------------
    PROCEDURE updatepltstatus(a_objectid      udt_id,
                              a_asofdate      DATE,
                              a_jobid         udt_id,
                              a_newstatus     VARCHAR2);

    /********************************************************************************************************
    - ManageDeleteRel is called on the Manage priority application job to delete the base relationship for the
    - filtered relationships in the grid
    ********************************************************************************************************/

    PROCEDURE managedeleterel(a_jobid         udt_id,
                              a_asofdate      DATE,
                              a_managejobid   udt_id);

    /*********************************************************************************************************
    - CreateReviewAppOnManageJob, Runs on the completion of the Relate PD applications process to
    - kick off the seprate workflows for the priority draw catagories
    **********************************************************************************************************/

    PROCEDURE createreviewapponmanagejob(a_processid udt_id, a_asofdate DATE);

    /*********************************************************************************************************
    - CreateProcessesOnManageJob, Runs on the completion of the Review Appliaction process to
    - kick off the next process as part of the catagories workflow
    **********************************************************************************************************/

    PROCEDURE createprocessesonmanagejob(a_processid udt_id, a_asofdate DATE);

    /*********************************************************************************************************
    - RaiseErrRankAndStatus is run on the No-Draw outcome of Review Appplications and the Complete outcome
    - of Draw and Enter Results processes, detarmining the the error based on catagory
    **********************************************************************************************************/

    PROCEDURE raiseerrrankandstatus(a_processid udt_id, a_asofdate DATE);
END pkg_prioritydraw;
/
