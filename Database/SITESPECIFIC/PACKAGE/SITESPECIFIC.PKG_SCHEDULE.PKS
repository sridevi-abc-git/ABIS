CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_SCHEDULE"
IS
    -- **************************************************************************
    -- File:        PKG_SCHEDULE.PKS
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

    -- Author  : LOREN
    -- Created : 6/6/2008 1:21:53 PM
    -- Purpose : ABCtask209: Create Reminders  Run Reminders nightly.

    ------------------------------------------------------------------------
    -- Types -- PUBLIC
    ------------------------------------------------------------------------
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    ---------------------------------------------------------------------------
    -- CreateReminderProcess -- PUBLIC
    -- Called by DBMS_SCHEDULER; ran daily.
    -- Creates reminder processes and assigns to the person who created
    -- the Reminder object, or the person assigned the reminder.
    --------------------------------------------------------------------------
    PROCEDURE createreminderprocess;



    ----start of system generated reminders
    --   *------------------------------------------------------------------------
    --   CreateSupervisorReminder
    --   On outcome of an Assign Process, create reminder for Supervisor for
    --   day after Invstigation Due Date.
    --   *------------------------------------------------------------------------
    PROCEDURE createsupervisorreminder(a_object udt_id, a_asofdate DATE);

    --   *------------------------------------------------------------------------
    --   DeleteSupervisorReminder
    --   On outcome of Conduct Process, remove Investigation Reminder if
    --   Investigation is completed after Investigation Due Date
    --   Also will remove Premises Expansion Request reminder, if exsits
    --   *------------------------------------------------------------------------
    PROCEDURE deletesupervisorreminder(a_object udt_id, a_asofdate DATE);


    --   *------------------------------------------------------------------------
    --    CreateTransferReminder
    --    On outcome of Assign App Inv Process, if App is Ownership Transfer,
    --    create 60 day reminder for Sup and LR.
    --   *------------------------------------------------------------------------
    PROCEDURE createtransferreminder(a_object        udt_id,
                                     a_asofdate      DATE,
                                     a_jobid         udt_id);


    --   *------------------------------------------------------------------------
    --   DeleteTransferReminder
    --   On outcome of Issue License Process, remove Transfer Reminder if
    --   Issue Date is earlier than Reminder Date
    --   *------------------------------------------------------------------------
    PROCEDURE deletetransferreminder(a_object        udt_id,
                                     a_asofdate      DATE,
                                     a_jobid         udt_id);



    --   *------------------------------------------------------------------------
    --    CreateOriginalAppReminder
    --    On outcome of Assign App Inv Process, if App is Original,
    --    create two 70 day reminders; one for Sup, one for LR.
    --   *------------------------------------------------------------------------
    PROCEDURE createoriginalappreminder(a_object        udt_id,
                                        a_asofdate      DATE,
                                        a_jobid         udt_id);


    --   *------------------------------------------------------------------------
    --   DeleteOriginalAppReminder - The System created two reminders.
    --   On outcome of Issue License Process for Original App
    --   remove two 70 day Reminders if Issue Date is earlier than Reminder Date
    --   *------------------------------------------------------------------------
    PROCEDURE deleteoriginalappreminder(a_object        udt_id,
                                        a_asofdate      DATE,
                                        a_jobid         udt_id);

    /*---------------------------------------------------------------------------
     * CleanLegalEntities() - PUBLIC
     *  Run by the Process Server, removes orphaned Legal Entities that are no longer
     *  related to any Applications or Licenses to prevent duplicate data from appearing
     *  in searches for Legal Entities.
     *-------------------------------------------------------------------------*/
    PROCEDURE cleanlegalentities(a_rows NUMBER DEFAULT 1000);

    --   *------------------------------------------------------------------------
    --    CreateEnfInvReminder
    --    On outcome of Assign Enforcement Investigation process
    --    create reminder for Supervisor; reminder date based on DepartmentPriority
    --    Priority is optional, so reminder is not always created.
    --   *------------------------------------------------------------------------
    PROCEDURE createenfinvreminder(a_object        udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id);


    --   *------------------------------------------------------------------------
    --   DeleteEnfInvReminder
    --   On outcome of Conduct Enf Inv Process
    --   Reminder is only created when Department Priority is populated.
    --   remove Reminder if completion Date is earlier than Reminder Date
    --   *------------------------------------------------------------------------
    PROCEDURE deleteenfinvreminder(a_object        udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id);


    --   *------------------------------------------------------------------------
    --    CreatePremExpanReminder
    --    On outcome of Assign Lic Inv Process
    --    create 10 day reminder if Admin Type is Premises Expansion Request
    --   *------------------------------------------------------------------------
    PROCEDURE createpremexpanreminder(a_object        udt_id,
                                      a_asofdate      DATE,
                                      a_jobid         udt_id);

    --   *------------------------------------------------------------------------
    --    CreateTempPermitReminder
    --    On outcome of Issue Temporary Permit process on App
    --    create reminder for 10 days days before date EffectiveTo. Assign to LR who
    --    is assigned the process p_IssueTemporaryPermit.
    --   *------------------------------------------------------------------------
    PROCEDURE createtemppermitreminder(a_objectid udt_id, a_asofdate DATE);

    PROCEDURE synclessthanzerobalance;
END pkg_schedule;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_SCHEDULE TO POSSEEXTENSIONS;
