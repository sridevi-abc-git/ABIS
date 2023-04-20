CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_BATCHTYPE"
IS
    -- **************************************************************************
    -- File:        PKG_BATCHTYPE.PKS
    -- Author:      CX
    --
    -- $Rev: 10 $
    -- $Date: 2018-08-20 10:49:39 -0700 (Mon, 20 Aug 2018) $
    -- Last Changed By:  $Author: tlord $
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

    /* *********************************************************************************************
     * Create Relationships for Batch Type
     * Batch type can be one of four values as follows:
     *  1. 'Produce Licenses'
     *  2. '1st Renewal Notices'
     *  3. '2nd Renewal Notices'
     *  4. 'Final Revocation Pending Letters'
     *  5. 'Auto Revoke License Types'
     *
     * When the Batch Type is 'Produce Licenses', this procedure creates relationships
     * from the passed in License Batch JobId to all the License Types where the licenseType
     * detail "IncludeInProduceLicenseBatch" is "Y".
     *
     * When the Batch type is '1st Renewal Notices' this procedure creates relationships from
     * the passed in License Batch JobId to all the License Types where the licenseType detail
     * 'IncludeIn1stRenewal' is 'Y' and the dup_RenewalDate is nominally 60 days in the future.
     *
     * When the Batch type is '2nd Renewal Notices' this procedure creates relationships from
     * the passed in License Batch JobId to all the License Types where the licenseType detail
     * 'IncludeIn2ndRenewal' is 'Y' and the dup_RenewalDate is nominally 50 days in the Past.
     *
     * When the Batch type is 'Final Revocation Pending Letters' this procedure creates relationships
     * from the passed in License Batch JobId to all the License Types where the licenseType detail
     * 'IncludeInRinalRevPending' is 'Y' and the dup_RenewalDate is nominally 80 days in the past.
     *
     * When the Batch type is 'Auto Revoke License Types' this procedure creates relationships
     * from the passed in License Batch JobId to all the License Types where the licenseType detail
     * 'IncludeInRevokeBatch' is 'Y' and the dup_RenewalDate is nominally 90 days in the past.
     ***********************************************************************************************/
    PROCEDURE relatependingltstobatch(a_jobid         udt_id,
                                      a_asofdate      DATE,
                                      a_batchtype     VARCHAR2,
                                      a_expirationdate DATE,
                                      a_color         VARCHAR2,
                                      a_dailyorrenewal VARCHAR2,
                                      a_licenseissuedate DATE,
                                      a_getbatchcandidates VARCHAR2);


    PROCEDURE emailerrororsuccess(a_toaddress     VARCHAR2,        --ToAddress
                                  a_subject       VARCHAR2,          --Subject
                                  a_body          VARCHAR2,             --Body
                                  a_priority      NUMBER, --[priority] --1 means high priority
                                  a_ccaddress     VARCHAR2,      --[ccaddress]
                                  a_relatedobjectid NUMBER --[relatedobjectid]
                                                          );


    /* *********************************************************************************************
     * Auto Revoke License Types.
     * This process automatically revokes license types related to the license batch. An autoRevoke
     * Process is related to the license type jobs and then completed with an autorevoke status.
     * If all license types related to a license are autorevoked a revoke license process is related to
     * the license.
     ************************************************************************************************/
    PROCEDURE autorevokelts(a_processid     udt_id,
                            a_asofdate      DATE,
                            a_jobid         udt_id);

    /* ******************************************************************************************************
     * Schedule Produce Licenses
     * Schedule the Produce Licenses procedure onto a specific Process Server
     ************************************************************************************************/
    PROCEDURE scheduleproducelicenses(a_processid     udt_id,
                                      a_asofdate      DATE,
                                      a_jobid         udt_id);


    /* ******************************************************************************************************
     * Produce Licenses.
     * This process automatically relates and completes an Activate License Type process for each License Type
     * related to the batch job and relates and completes an Activate License process for each License related
     * to the license types as outlined below.
     *
     * TYPE*   License         License  DoNotActivate    Include  Activat Activat    Set           Set
     *         Status          Type      Flag            In       License License   DoNotActivate  IncludeInProduceLicenseBatch
     *                         Status    Value           Batch             Type       To:          To:
     * ------------------------------------------------------------------------------------------------------
     * B        p                P        F                Y        Y        Y        N/C           N
     * B        P                P        T                Y        Y        N        N/C           N
     * B        P                A        F                Y        Y        N        N/C           N
     * B        P                A        T                Y        Y        N        N/C           N
     * B        p                RP       F                Y        Y        Y        N/C           N
     * B        P                RP       T                Y        Y        N        N/C           N
     * B        P                S        F                Y        Y        N        N/C           N
     * B        P                S        T                Y        Y        N        N/C           N
     * ------------------------------------------------------------------------------------------------------
     * B        H/SLMS-H         *        *                Y        N        N        N/C           N
     * ------------------------------------------------------------------------------------------------------
     * B        SUS              *        *                Y        N        N        N/C           N
     * -------------------------------------------------------------------------------------------------------
     * B        A                P        F                Y        Y        Y        N/C           N
     * B        A                P        T                Y        Y        N        N/C           N
     * B        A                A        F                Y        Y        N        N/C           N
     * B        A                A        T                Y        Y        N        N/C           N
     * B        A                RP       F                Y        Y        Y        N/C           N
     * B        A                RP       T                Y        Y        N        N/C           N
     * B        A                S        F                Y        Y        N        N/C           N
     * B        A                S        T                Y        Y        N        N/C           N
     * -------------------------------------------------------------------------------------------------------
     *
     * * M = Manual, B=Batch
     ************************************************************************************************/
    PROCEDURE producelicenses(a_processid     udt_id,
                              a_asofdate      DATE,
                              a_jobid         udt_id);

    /* ******************************************************************************************************
     * Activate Licenses.
     * This process is designed to be called for a manually related Activate License process (to a License).
     * This procedure automatically relates and completes an Activate License Type process as outlined by
     * the truth table below.
     *
     * TYPE*   License         License  DoNotActivate    Include  Activat Activat    Set           Set
     *         Status          Type      Flag            In       License License   DoNotActivate  IncludeInProduceLicenseBatch
     *                         Status    Value           Batch             Type       To:          To:
     * -------------------------------------------------------------------------------------------------------
     * M        P                P        F                N/A      Y        Y        N/C           N/C
     * M        P                P        T                N/A      Y        Y        F             N/C
     * M        P                A        F                N/A      Y        N        N/C           N/C
     * M        P                A        T                N/A      Y        N        F             N/C
     * M        P                RP       F                N/A      Y        N        N/C           N/C
     * M        P                RP       T                N/A      Y        N        N/C           N/C
     * M        P                S        F                N/A      Y        N        N/C           N/C
     * M        P                S        T                N/A      Y        N        N/C           N/C
     * --------------------------------------------------------------------------------------------------------
     * M        A                P        F                N/A      Y        Y        N/C           N/C
     * M        A                P        T                N/A      Y        Y        F             N/C
     * M        A                A        F                N/A      Y        N        N/C           N/C
     * M        A                A        T                N/A      Y        N        F             N/C
     * M        A                RP       F                N/A      Y        N        N/C           N/C
     * M        A                RP       T                N/A      Y        N        N/C           N/C
     * M        A                S        F                N/A      Y        N        N/C           N/C
     * M        A                S        T                N/A      Y        N        N/C           N/C
     * --------------------------------------------------------------------------------------------------------
     * M        SUS              *        *                N/A      Y        N        N/C           N/C
     * -------------------------------------------------------------------------------------------------------
     * M        H/SLMS-H         P        F                N/A      Y        Y        N/C           N/C
     * M        H/SLMS-H         P        T                N/A      Y        Y        F             N/C
     * M        H/SLMS-H         A        F                N/A      Y        N        N/C           N/C
     * M        H/SLMS-H         A        T                N/A      Y        N        F             N/C
     * M        H/SLMS-H         RP       F                N/A      Y        N        N/C           N/C
     * M        H/SLMS-H         RP       T                N/A      Y        N        N/C           N/C
     * M        H/SLMS-H         S        F                N/A      Y        N        N/C           N/C
     * M        H/SLMS-H         S        T                N/A      Y        N        N/C           N/C
     *
     *
     * * M = Manual, B=Batch
     ********************************************************************************************************/
    PROCEDURE activatelicense(a_processid     udt_id,
                              a_asofdate      DATE,
                              a_jobid         udt_id);

    /*-------------------------------------------------
     -- ActivateSecondaryLicenseTypes()
     -- Upon completion of the Activate License Type process
     -- this will activate all secondary license types.
     -----------------------------------------------------*/

    PROCEDURE activatesecondarylicensetypes(a_processid     udt_id,
                                            a_asofdate      DATE,
                                            a_jobid         udt_id);

    /* *********************************************************************************************
     * Set Batch Flags On Batch Jobs.
     * This process automatically the batch flags appropriately on the following batch jobs,
     * "IncludeIn1stRenewal", "IncludeIn2ndRenewal", "IncludeInFinalRevPending".
     ************************************************************************************************/
    PROCEDURE setbatchflagsonbatchjobs(a_processid     udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id,
                                       a_batchtype     VARCHAR);



    /* ***************************************************************************************************************
     * Set Batch Flags.
     * This process provides a shortcut to manually setting the batch flags, "IncludeInProduceLicenseBatch", "IncludeIn1stRenewal",
     * "IncludeIn2ndrenewal", "IncludeInFinalRevPending", and "IncludeInRevokeBatch". This process will default the
     * values to 'N' (in the above apecified order), only the 'Y' values need be specified using either positional or
     * named notation, only the License Type Jobid is required.
     *****************************************************************************************************************/
    PROCEDURE setbatchflags(a_lictypejobid  udt_id,
                            a_includeinproducelicensebatch CHAR DEFAULT 'N',
                            a_includeindailybatch CHAR DEFAULT 'N',
                            a_includein1strenewal CHAR DEFAULT 'N',
                            a_includein2ndrenewal CHAR DEFAULT 'N',
                            a_includeinfinalrevpending CHAR DEFAULT 'N',
                            a_includeinrevokebatch CHAR DEFAULT 'N',
                            a_isgreendone   CHAR DEFAULT 'N',
                            a_ispinkdone    CHAR DEFAULT 'N');

    /* ***************************************************************************************************************
     * Set Batch Flags Wrapper.
     * This Procedure provides a the functionality to call the SetBatchFlags procedure from Posse, without forcing other
     * functions to pass in a non-used Object Id and Date. Again just as with SetBatchFlags this process will default the
     * values to 'N' (in the above apecified order), only the 'Y' values need be specified using either positional or
     * named notation, only the ObjectID, AsOfDate, and License Type Jobid is required.
     *****************************************************************************************************************/
    PROCEDURE setbatchflagswrap(
        a_objectid      udt_id,
        a_asofdate      DATE,
        a_lictypejobid  udt_id,
        a_includeinproducelicensebatch CHAR DEFAULT 'N',
        a_includeindailybatch CHAR DEFAULT 'N',
        a_includein1strenewal CHAR DEFAULT 'N',
        a_includein2ndrenewal CHAR DEFAULT 'N',
        a_includeinfinalrevpending CHAR DEFAULT 'N',
        a_includeinrevokebatch CHAR DEFAULT 'N',
        a_isgreendone   CHAR DEFAULT 'N',
        a_ispinkdone    CHAR DEFAULT 'N');

    ----------------------------------------------------------------------------------------------------
    --  GetBatchPenaltyCandidates()
    --  This will relate License Type Candidates to the License Batch Job.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE getbatchpenaltycandidates(a_jobid         udt_id,
                                        a_asofdate      DATE,
                                        a_expirationdate DATE,
                                        a_ren50orren100 VARCHAR2);

    /*-------------------------------------------------
     -- CopyProduceLicenseTypes()
     -- Populates the License Types grid on the Produce Licenses process.
     -----------------------------------------------------*/
    PROCEDURE copyproducelicensetypes(a_objectid udt_id, a_asofdate DATE);

    /*-------------------------------------------------
     -- SetFlagsforProduceLicenses()
     -- Resets the Produce License Batch flag when applicable.
     -----------------------------------------------------*/
    PROCEDURE setflagsforproducelicenses(a_objectid udt_id, a_asofdate DATE);

    /*--------------------------------------------------------
    --SetPrintFlagForManualProduce()
    --Sets the print flag on the duplicate objects based on the
    --selected secondaries from the manual produce license process
    ----------------------------------------------------------*/
    PROCEDURE setprintflagformanualproduce(a_objectid      udt_id,
                                           a_asofdate      DATE);

    /*-------------------------------------------------
     -- LogTypeofIssuance ()
     -- Logs the type of issuance using License Type and Secondary License Type Ids
     --    on the print outcome of the Produce License Batch
     -----------------------------------------------------*/
    PROCEDURE logtypeofissuance(a_processid udt_id, a_asofdate DATE);

    /*-------------------------------------------------
     -- SetTypeofIssuance ()
     -- Sets the type of issuance on License Types and Secondary Relationships from the log table.
     --   This procedure is used by the dbms_Scheduler every evening.
     -----------------------------------------------------*/
    PROCEDURE settypeofissuance;

    /*-------------------------------------------------
    -- SetDuplicatesTOI ()
    -- Set the type of issueance on the duplicate object when the
    -- type of issueance is updated on the override
    -----------------------------------------------------*/
    PROCEDURE setduplicatestoi(a_objectid udt_id, a_asofdate DATE);

    /*-------------------------------------------------
    -- SetDuplciatesReadyToIssue ()
    -- Set the Ready to Issue Date on the duplicate object
    -- when the ready to issue date is updated on the override
    -----------------------------------------------------*/
    PROCEDURE setduplciatesreadytoissue(a_objectid udt_id, a_asofdate DATE);


    /*------------------
    -- SetREVPStatus()
    -- This will run on completion of the Send Final RevP Letters process on the License Batch job.
    -- It will loop through the LTs on the batch and set the status of any Active or Surrendered LT
    -- to Rev Pending.
    */
    ------------------

    PROCEDURE setrevpstatus(a_objectid      udt_id,
                            a_asofdate      DATE,
                            a_jobid         udt_id);

    /*-----------------
    --
    --
    --
    --
    -------------------*/
    PROCEDURE setrevpstatussecondaries(a_objectid udt_id, a_asofdate DATE);

    /*------------------
    -- DeleteLTFromActiveBatches()
    -- This will Delete a LicenseType from any batch Job that it is on. Added when the License Type
    -- changed from stored to external so AC can delete license types from the batch.
    */
    ------------------
    PROCEDURE deleteltfromactivebatches(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * GetProcessTypeForBatch() - PRIVATE
     *   Based on the batch type, return the process id that the LicenseBatch
     *   job would run
     *-------------------------------------------------------------------------*/
    PROCEDURE getprocesstypeforbatch(a_batchtype        VARCHAR2,
                                     a_processdefid OUT udt_id,
                                     a_processname  OUT VARCHAR2,
                                     a_processstatus OUT VARCHAR2);


    /* *********************************************************************************************
       * TESTLogging
       ***********************************************************************************************/
    /*procedure TESTLogging ( a_Message   varchar2
    );*/
    /**********************************************************************************************
     * BatchLogging
     ***********************************************************************************************/
    PROCEDURE batchlogging(a_jobid         udt_id,
                           a_processid     udt_id,
                           a_message       VARCHAR2,
                           a_totalexpectedcount NUMBER);

    /****************************************************************************
     * Scheduled Batch Processes
     * Distribute Batch items among scheduled-to-complete processes to break up
     *   the workload
     ***************************************************************************/
    PROCEDURE schedulebatchprocesses(a_objectid      udt_id,
                                     a_asofdate      DATE,
                                     a_jobid         udt_id);

    /****************************************************************************
     * BatchProcessCompletion
     * Send email report and trigger job completion if last batch process is
     *   complete
     ***************************************************************************/
    PROCEDURE batchprocesscompletion(a_processid     udt_id,
                                     a_asofdate      DATE,
                                     a_jobid         udt_id);

    /****************************************************************************
     * ScheduleBatchProcessing
     * Scheduled the procedure that initiates the batch processing
     ***************************************************************************/
    PROCEDURE schedulebatchprocessing(a_processid     udt_id,
                                      a_asofdate      DATE,
                                      a_jobid         udt_id);

    /* *********************************************************************************************
    * Create Notification Records
    ***********************************************************************************************/
    PROCEDURE sendnotifications;
END pkg_batchtype;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_BATCHTYPE TO EXTENSION;

GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_BATCHTYPE TO KAURP;

GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_BATCHTYPE TO LORDT;

GRANT EXECUTE ON SITESPECIFIC.PKG_BATCHTYPE TO POSSEEXTENSIONS;
