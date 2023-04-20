CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_ISSUELICENSE"
AS
    -- **************************************************************************
    -- File:        PKG_ISSUELICENSE.PKS
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

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    ----------------------------------------------------------------------------------------------------
    --   * GetEndPointId() -- PUBLIC
    -- Get the ToEndPointId for a given relationsihpdef.
    -- Returns t_ToEndPointId, which can be used for creating a new relationship between objects.
    -- Package was developed using this Proc, rather than api.pkg_configquery.EndPointIdForName()
    -- A mix of both are currently used in the package. GetEndPointId should be replaced by API function.
    ----------------------------------------------------------------------------------------------------
    FUNCTION gettoendpointid(a_relationshipdefid udt_id,
                             a_objectdefid   udt_id)
        RETURN udt_id;

    ----------------------------------------------------------------------------------------------------
    --   * GetAppTypeLaunchLic() -- PUBLIC
    -- Using parameter of application objectid
    -- Get the type of application, and call the appropriate issue license procedure
    -- Called as an Activity to Run when
    -- Process TMP Issue License on j_Application is outcomed with TMP Issued.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE getapptypelaunchlic(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_jobid         udt_id);

    ----------------------------------------------------------------------------------------------------
    --   * SetExpMonthYear()
    -- Using parameter of application objectid
    -- Set the ExpirationMonth and ExpirationYear using Primary License Type object data if exists.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE setexpmonthyear(a_objectid      udt_id,
                              a_asofdate      DATE,
                              a_prilictypeid  udt_id,
                              a_jobid         udt_id);

    -------------------------------------------------------------------------------
    -- * IssueOriginalLicense() -- PUBLIC
    -- Create Original License Job, and copy all appropriate details and structure
    -- from the Application Job that caused the License Job.
    -- Called by procedure GetAppTypeLaunchLic.
    -- Receives Application Job objectid.
    -- *---------------------------------------------------------------------------
    PROCEDURE issueoriginallicense(a_appobjectid   udt_id,
                                   a_processobjid  udt_id DEFAULT NULL);

    -------------------------------------------------------------------------------
    -- * IssueTransferLicense() -- PUBLIC
    -- Create new license and copy all appropriate details and structure
    -- from the Application Job that caused the License Job.
    -- Called by procedure GetAppTypeLaunchLic.
    -- Receives Application Job objectid.
    -- *---------------------------------------------------------------------------
    PROCEDURE issuetransferlicense(a_appobjectid   udt_id,
                                   a_processobjid  udt_id DEFAULT NULL);

    PROCEDURE issuetransfertoactivelicense(
        a_appobjectid   udt_id,
        a_processobjid  udt_id DEFAULT NULL);

    -------------------------------------------------------------------------------
    -- * IssueChangeLicense() -- PUBLIC
    -- Change existing license details and structure
    -- per information from the Application Job.
    -- Called by procedure GetAppTypeLaunchLic.
    -- Receives Application Job objectid.
    -- *---------------------------------------------------------------------------
    PROCEDURE issuechangelicense(a_appobjectid   udt_id,
                                 a_processobjid  udt_id DEFAULT NULL);

    -------------------------------------------------------------------------------
    -- * IssueOneDay() -- PUBLIC
    -- Procedure to run on Payment Constructor to Issue the One Day License automatically
    -- if all the fees have been paid.
    -- *---------------------------------------------------------------------------
    PROCEDURE issueoneday(a_objectid udt_id, a_asofdate DATE);

    /*-------------------------------------------------
     -- FillLicenseTypesGrid()
     -- Populates the License Types grid on the Issue License process.
     -----------------------------------------------------*/
    PROCEDURE filllicensetypesgrid(a_objectid udt_id, a_asofdate DATE);

    /*------------------------------------------------------------------------------------------------
      --  IssueSLTs()     --Public
      --  This procedure is called within the Issue procedures and will issue only the secondary LTs
      -- when and only when the primary is issued and the SLT has the issue check box flagged.
      ----------------------------------------------------------------------------------------------*/

    PROCEDURE issueslt(a_issueprocessid udt_id, a_jobid udt_id);

    /*----------------------------------------------------------------------------------------------------
      --  IssueApp()     --Public
      --  This procedure is called on completion of the Issue Process and if all license types are issued
      -- within the process this procedure will change the status of the Application to Issued.
      ----------------------------------------------------------------------------------------------------*/

    PROCEDURE issueapp(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id);

    /***********************
    -- LogLicenseTransfer() PUBLIC
    -- This is to log the issuance of a Transfer or Change
    -- at the License Type level.
    ***********************/

    PROCEDURE loglicensetransfer(a_transtoltjobid VARCHAR2,
                                 a_transtoltcode VARCHAR2,
                                 a_transtolicnum VARCHAR2,
                                 a_pltobjectid   udt_id,
                                 a_appjobid      udt_id);

    /***********************
    -- ValidatePaymentCheck() PUBLIC
    -- This procedure runs on issuance of a licensetype
    ***********************/

    PROCEDURE validatepaymentcheck(a_processid        udt_id,
                                   a_asofdate         DATE,
                                   a_jobid            udt_id,
                                   a_licensetypecode  VARCHAR2,
                                   a_processpayment   VARCHAR2,
                                   a_continue     OUT VARCHAR2);

    PROCEDURE validatepaymentcheck(a_processid     udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id);

    PROCEDURE openaccusationserror(a_processid     udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id);

    PROCEDURE deletewithdrawapp(a_objectid      udt_id,
                                a_asofdate      DATE,
                                a_jobid         udt_id);

    /*********************************************************************************
     * GenIssueCatererEventProcesses() PUBLIC
     * This procedure deletes the incomplete Withdraw Application processes on the Job
     *********************************************************************************/
    PROCEDURE genissuecaterereventprocesses(a_objectid      udt_id,
                                            a_asofdate      DATE,
                                            a_jobid         udt_id,
                                            a_count         NUMBER);

    /*********************************************************************************
     * IssueMultiCatererEventAuths() PUBLIC
     * This procedure deletes the incomplete Withdraw Application processes on the Job
     *********************************************************************************/
    PROCEDURE issuemulticaterereventauths(a_objectid udt_id, a_asofdate DATE);
END pkg_issuelicense;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_ISSUELICENSE TO POSSEEXTENSIONS;
