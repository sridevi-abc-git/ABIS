CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_LICENSETYPE" as
-- ****************************************************************************
-- File:        PKG_LICENSETYPE.pks  
-- Author:      CX
--
-- $Rev: 4056 $  
-- $Date: 2018-04-07 15:31:03 -0700 (Sat, 07 Apr 2018) $
-- Last Changed By:  $Author: tlord $
--
-- History:
-------------------------------------------------------------------------------
--    Date     By    WO       Comment
-- 04/07/2018 TJL  14255   Add new Procedure: CorrectPriorityRel()  
-- ****************************************************************************

  subtype udt_Id is api.pkg_Definition.udt_Id;
  subtype udt_IdList is api.pkg_definition.udt_IdList;
  type udt_LicenseTypeCodes is table of varchar2(3);

  /*Run using toolbox 'Constructor' on Post Verify of the
  License Type job
  This procedure is used rather than a configured mask so
  that the ExternalFileNum can be set from the value on the
  License job.*/
  procedure SetExternalFileNumber (
    a_jobid                    udt_id,
    a_asofdate                 date
  );
  
  
----------------------------------------------------------------------------------------------------
--  TerminateLicenseType() -- PUBLIC          
--  On outcome of the Terminate License process on the License job, 
--  Auto-complete the Terminate License Type process on each related License Type job.
-- 
----------------------------------------------------------------------------------------------------
 Procedure TerminateLicenseType(
   a_ProcessId udt_id
  ,a_AsOfDate  date
  ,a_JobId     udt_id);
  
  Procedure RevokeSuspendLicenseType (
    a_ProcessId udt_id,
    a_AsOfDate date,
    a_JobId udt_id,
    a_Revoke char,
    a_Suspend char);

  /*---------------------------------------------------------------------------
   * AddPendingLTCsToLT
   *   This procedure will run on Add Permit/License Type process and add a
   *   Pending License Type Category for all secondary License Type Category
   *   on the License Type.
   *-------------------------------------------------------------------------*/
  procedure AddPendingLTCsToLT (
    a_ObjectId          udt_Id,
    a_AsOfDate          date,
    a_JobId             udt_Id
  );
  
  /*---------------------------------------------------------------------------
   * AddPendingLTCsToAddLTC
   *   This procedure will run as an activity on Add Permit/License Type 
   *   process and add a relationship between all Pending License Type 
   *   Categories on the License Type to the process. This is done for a
   *   history of what Peding LTCs were changed.
   *-------------------------------------------------------------------------*/
  procedure RelatePendingLTCsToAddLTC (
    a_ObjectId          udt_Id,
    a_AsOfDate          date,
    a_JobId             udt_Id
  );

  /*---------------------------------------------------------------------------
   * Change Status for HQ processes
   *   This procedure will run as an activity on the Surrender License Type, 
   *   Terminate License Type and Re-activate License Type processes that 
   *   will change the status appropriately by creating the Change Status process
   *   and completing it with the applicable outcome.
   *-------------------------------------------------------------------------*/
  procedure ChangeStatusForHQProcesses (
    a_ProcessId         udt_Id,
    a_AsOfDate          date,
    a_JobId             udt_Id);
    
   /*---------------------------------------------------------------------------
   * IssueLicense
   *   This procedure will run as an activity on Issue License process and will
   * update the or create new Secondary License Types on the License Type job.
   *-------------------------------------------------------------------------*/
  procedure IssueLicense (
    a_ObjectId          udt_Id,
    a_AsOfDate          date,
    a_JobId             udt_Id);

  /*--------------------------------------------------
  *  TerminateLicense() -- PUBLIC
  *
  *  This procedure terminates a License when all related LT are in the status of cancelled.
  *  It will put the License in the status of Non-Renewed under the same circumstances if
  *  one of the LTs are in a Non-Renewed status.
  *-------------------------------------------------*/
  procedure TerminateLicense(
    a_ProcessId udt_Id, a_AsOfDate date);
    
/*----------------------------------------------------------------------------------------------
  --  FillUnissueLTGrid()     --Public 
  --  Populates the License Types grid on the UnIssue License Type process.
  ----------------------------------------------------------------------------------------------*/ 
  procedure FillUnissueLTGrid(
      a_ObjectId udt_Id,
      a_AsOfDate date
    );
      
   /*---------------------------------------------------------------------------
   * UnissueLicenseType
   *   This procedure will run as an activity on Unissue License Type process 
   * and will clear the Expiration Date.
   *-------------------------------------------------------------------------*/
  procedure UnissueLicenseType (
    a_ObjectId              udt_Id,
    a_AsOfDate              date,
    a_PrimaryOrSecondary    varchar2);
    
----------------------------------------------------------------------------------------------------
--  SetExpMonthYear()
-- Using parameter of application objectid
-- Set the ExpirationMonth and ExpirationYear using Primary License Type object data if exists.
---------------------------------------------------------------------------------------------------
  procedure SetExpMonthYear (
      a_ObjectId       udt_id,
      a_AsOfDate       date,
      a_JobId          udt_id
   );

  function ValidMasterLicenseTypesonPLT (a_ObjectId         udt_Id
  ) return udt_LicenseTypeCodes;
  
  function ValidBranchLicenseTypesonPLT (a_ObjectId         udt_Id
  ) return udt_LicenseTypeCodes;

  procedure VerifyLicenseTypeonPLT (a_RelationshipId   udt_Id,
                                    a_AsOfDate         date
  );  

---------------------------------------------------------------------------------------------------  
-- ReinstateLicType
---------------------------------------------------------------------------------------------------
  procedure ReinstateLicType (
      a_processid   udt_id,
      a_AsOfDate    date,
      a_OverrideBalanceOwingCheck char      
      
   );
   
   /*--------------------------------------------------------------------------
   * ChangeSecLicTypeStatus() -- PUBLIC
   * Sets all the secondary license types on a license type job that aren't
   * cancelled to a specified status.
   *-------------------------------------------------------------------------*/
  procedure ChangeSecLicTypeStatus(a_processid   udt_id,
                                   a_AsOfDate    date,
                                   a_JobId       udt_id,
                                   a_Status      varchar2);
                                   
  /*-------------------------------------------------------------------------
  * SetBranchDetail() - Public
  * This procedure is used to set details on the Branch LTs based off their
  * Master LT
  *------------------------------------------------------------------------*/

  procedure SetBranchDetail(a_Objectid                    udt_id, 
                            a_AsofDate                    date,
                            a_SourceColumnName            varchar2,
                            a_TargetColumnName            varchar2);     
                            
----------------------------------------------------------------------------------------------------
--   * SetExpMonthYear()
--Run on outcome of the produce license batch to set the expiring month and year when the expiration date is null
----------------------------------------------------------------------------------------------------
  procedure SetExpMonthYearBatch (
      a_ObjectId       udt_id,
      a_JobId          udt_id,
      a_AsOfDate       date
   );                               

  /*-------------------------------------------------------------------------
  * CorrectSecondaryRel() - Public
  * This procedure is used on the outcome of the p_CorrectSecondary process
  * to move the relationship of a chosen Secondary from one Primary LT to
  * another.
  *------------------------------------------------------------------------*/

  procedure CorrectSecondaryRel(a_Objectid             udt_id,
                                a_AsofDate             date,
                                a_SecondaryLTCObjectId udt_id,
                                a_ToPrimaryLTObjectId  udt_id);
 
  /*-------------------------------------------------------------------
  -- SetPrimaryLTStatus()
  -- This runs on an outcome of a process and sets the PLT/SLT statuses
  -- to the status the outcome is going to.
  */-------------------------------------------------------------------
  procedure SetPrimaryLTStatus(a_ObjectId     udt_Id,
                               a_AsOfDate     date,
                               a_JobId        udt_Id);
  
  /*-------------------------------------------------------------------------
  *   TJL - WO 14255 02/28/2018
  * CorrectPriorityRel() - Public
  * This procedure is used to add back the priority license type priority 
  * when the license type is changed on priority application 
  *------------------------------------------------------------------------*/

  procedure CorrectPriorityRel(a_Objectid             udt_id,
                               a_AsofDate             date);

  /*-------------------------------------------------------------------------
  *   Priority Item #5B - GenerateSLTFees
  *   Author: Shane Gilbert
  *   This procedure will validate and generate fees when secondary license types 
  *   added to a pending application
  *   Called from the Primary License Type
  *------------------------------------------------------------------------*/
  procedure GenerateSLTFees (a_Objectid             udt_id,
                             a_AsofDate             date) ;    

  /*-------------------------------------------------------------------------
  *   Priority Item #5B - RemoveSLTFees
  *   Author: Shane Gilbert  
  *   This procedure will remove secondary license type fees when removed and 
  *   no payments have been made 
  *
  *   Called from the deleting procedure
  *------------------------------------------------------------------------*/                             
  procedure RemoveSLTFees (a_Objectid             udt_id,
                             a_AsofDate             date);        
                              
end pkg_LicenseType;

/
