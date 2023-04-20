CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_LICENSETYPE" is
-- ****************************************************************************
-- File:        PKG_LICENSETYPE.pkb  
-- Author:      CX
--
-- $Rev: 4056 $  
-- $Date: 2018-04-07 15:31:03 -0700 (Sat, 07 Apr 2018) $
-- Last Changed By:  $Author: tlord $
--
-- History:
-------------------------------------------------------------------------------
--    Date     By    WO       Comment
-- 04/07/2018 TJL  14255    Add new Procedure: CorrectPriorityRel() 
-- 06/03/2020 TJL  21754    Fixed column definition in UnissueLicenseType Procedure.
-- ****************************************************************************

  procedure SetExternalFileNumber (
    a_jobid                    udt_id,
    a_asofdate                 date
  ) is
    t_ExternalFileNum          varchar2(15);
    t_LicenseTypeCode          varchar2(2);
    t_LicenseTypeAppend        number;
  begin
    select ExternalFileNum, LicenseTypeCode
      into t_ExternalFileNum, t_LicenseTypeCode
      from query.j_Licensetype
     where jobid = a_jobid;
    
    if t_ExternalFileNum is null then
      begin
      select j.ExternalFileNum
        into t_ExternalFileNum
        from api.relationships r
        join api.jobs j on j.jobid = r.ToObjectId
       where r.EndPointId = api.pkg_configquery.EndPointIdForName('j_LicenseType', 'License')
         and r.FromObjectId = a_jobid;
      exception when no_data_found then
        api.pkg_errors.RaiseError(-20000,'The License does not have an ExternalFileNum defined');
      end;
      

      api.pkg_jobupdate.SetExternalFileNum(a_jobid,t_LicenseTypeCode||'-'||t_ExternalFileNum);


    end if;
  end;
  
  
   Procedure TerminateLicenseType(
   a_ProcessId udt_id
  ,a_AsOfDate  date
  ,a_JobId     udt_id)is

 t_LTProcessObjId udt_id;
 t_LicStatus        varchar2(60);
 t_ChangeStatProc   udt_id;
 begin

    --Set the License Status to Non-Renewed or Canceled based on the LTs
   select case when count(1) > 0 then
           'Non-Renewed' else
           'Canceled' end
   into t_LicStatus
   from api.relationships r
   join query.j_licensetype lt on lt.ObjectId = r.ToObjectId
   where r.FromObjectId = a_JobId
   and r.EndpointId = api.pkg_configquery.EndPointIdForName('j_License', 'LicenseType')
   and lt.StatusName = 'NREN';
   
   t_ChangeStatProc := api.pkg_processupdate.New(a_JobId, 
                                                 api.pkg_ConfigQuery.ObjectDefIdForName('p_ChangeStatus'), 
                                                 'System Generated.', 
                                                 NULL, 
                                                 NULL, 
                                                 NULL);
   api.pkg_processupdate.Complete(t_ChangeStatProc, t_LicStatus);
 
   for c_1 in (select -- Find all the License Types associated with this License
               r.ToObjectId
              ,lt.StatusName
               from api.relationships r
               join query.j_licensetype lt on lt.ObjectId = r.ToObjectId
               where r.FromObjectId = a_JobId
               and r.EndpointId = api.pkg_configquery.EndPointIdForName('j_License', 'LicenseType')
               and lt.StatusName NOT IN ('CANCEL','SLMSRV','AUTREV','DEPREV','NREN', 'WTHDRN', 'DENIED', 'VOIDED'))loop 
   
     t_LTProcessObjId := api.pkg_processupdate.New(
                              c_1.ToObjectid
                             ,api.pkg_ConfigQuery.ObjectDefIdForName('p_TerminateLicenseType')
                             ,('License Type Terminated by System icw termination of License.')
                             ,NULL,NULL,NULL);
                                               
     api.pkg_processupdate.Complete(t_LTProcessObjId,'Cancel');       
     
   --Terminate Secondary License Types
    for c in (select slt.relationshipid, slt.Status, slt.LicenseTypeCount
                from query.r_licensetypeltcatsecondary slt 
               where slt.LicenseTypeJobId = c_1.ToObjectid --License Type Jobid
                 and slt.status != 'CANCELED') loop
      --Set Status to Canceled
      api.pkg_columnupdate.SetValue(c.relationshipid, 'Status', 'CANCELED');
	  sitespecific.pkg_BatchType.SetBatchFlags(c.relationshipid); --Sheik 11/21/2016 WO#8925 Unchecking secondary checkboxes from override area
    end loop;

   end loop; -- All the License Types associated with this License
   

               
 end TerminateLicenseType;
  
  Procedure RevokeSuspendLicenseType (
    a_ProcessId udt_id,
    a_AsOfDate date,
    a_JobId udt_id,
    a_Revoke char,
    a_Suspend char)
  is
    t_LTProcessId udt_id;
    t_ChangeStatusProcessTypeId udt_id;
    t_RevokeLTProcessTypeId udt_id;
  begin
    t_ChangeStatusProcessTypeId := api.pkg_configquery.ObjectDefIdForName('p_ChangeStatus');
    t_RevokeLTProcessTypeId := api.pkg_configquery.ObjectDefIdForName('p_RevokeLicenseType');
    
    for c_1 in (select r.ToObjectId, 
                       lt.StatusName
                from api.relationships r
                join query.j_licensetype lt on lt.ObjectId = r.ToObjectId
                where r.FromObjectId = a_JobId
                and r.EndpointId = api.pkg_configquery.EndPointIdForName('j_License', 'LicenseType')
                and lt.StatusName not in ('CANCEL','SLMSRV','AUTREV','DEPREV','NREN', 'WTHDRN', 'DENIED', 'VOIDED')) loop   
      if a_Revoke = 'Y' then
        t_LTProcessId := api.pkg_processupdate.new(c_1.toobjectid, t_RevokeLTProcessTypeId,'License Type Revoked as a result of an Accusation job.',null,null,null);
        api.pkg_processupdate.Complete(t_LTProcessId,'Dept Revoke');
      elsif a_Suspend = 'Y' then
        t_LTProcessId := api.pkg_processupdate.new(c_1.toobjectid, t_ChangeStatusProcessTypeId,'License Type Suspended as a result of an Accusation job.',null,null,null);
        api.pkg_processupdate.Complete(t_LTProcessId,'Suspended');
      end if;

      for c in (select slt.relationshipid, 
                       slt.Status, 
                       slt.LicenseTypeCount
                from query.r_licensetypeltcatsecondary slt 
                where slt.LicenseTypeJobId = c_1.ToObjectid
                and slt.status not in ('CANCELED')) loop
        if a_Revoke = 'Y' then
          api.pkg_columnupdate.SetValue(c.relationshipid, 'Status', 'DEPARTMENT REVOKED');
        elsif a_Suspend = 'Y' then
          api.pkg_columnupdate.SetValue(c.relationshipid, 'Status', 'SUSPENDED');
        end if;
      end loop;
    end loop;
  end RevokeSuspendLicenseType;

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
  ) is
  t_RelationshipId      udt_Id;
  t_LTCDefId udt_id := api.pkg_configquery.ObjectDefIdForName('o_LicenseTypeCategory');
  begin
    
    -- Remove old Pending rels from License Type jobs
    For x in (select plt.RelationshipId
                from query.j_License l
                join query.r_LicenseLicenseType llt
                  on l.JobId = llt.LicenseJobId
                join query.j_LicenseType lt
                  on llt.LicenseTypeJobId = lt.JobId
                join query.r_LicenseTypePendSecLTCat plt
                  on lt.JobId = plt.LicenseTypeJobId
               where l.JobId = a_JobId) Loop
      for d in (select d.duplicateid objectid
                  from api.relationships r 
                  join api.endpoints ep on ep.endpointid = r.endpointid
                  join sitespecific.duplicate_t d 
                    on d.licensetypecategoryobjectid = r.toobjectid
                   and (d.licensetypejobid = r.fromobjectid or d.primarylicensetypeobjectid = r.fromobjectid)
                 where r.relationshipid = x.RelationshipId
                   and ep.ToObjectDefId = t_LTCDefId) loop
        null;--api.pkg_objectupdate.Remove(d.objectid, sysdate); 
      end loop;
      api.pkg_columnupdate.SetValue(x.relationshipid, 'SkipDestructorProcedure', 'Y');
                       
      api.pkg_RelationshipUpdate.Remove(x.RelationshipId);
    End Loop;
    
    -- Find all License Type Jobs related to License Job and their secondary LTCs
    for c in (select ltltc.LicenseTypeJobId, ltltc.LicenseTypeCategoryObjectId, ltltc.LicenseTypeCount, ltltc.Status
                from query.r_LicenseLicenseType llt
                join query.r_LicenseTypeLTCatSecondary ltltc
                  on ltltc.LicenseTypeJobId = llt.LicenseTypeJobId
               where llt.LicenseJobId = a_JobId) loop           
        
      -- Then create Pending LTCs based on secondary
      t_RelationshipId := api.pkg_RelationshipUpdate.New(api.pkg_ConfigQuery.EndPointIdForName('j_LicenseType', 'LicTypeCatPending'), 
                                                         c.LicenseTypeJobId, 
                                                         c.LicenseTypeCategoryObjectId);

      --api.pkg_ColumnUpdate.SetValue(t_RelationshipId, 'LicenseTypeCount', c.LicenseTypeCount);
      api.pkg_columnupdate.SetValue(t_RelationshipId, 'Status', c.status);
      api.pkg_columnupdate.SetValue(t_Relationshipid, 'SystemAdded', 'Y');

    end loop;
  end;
  
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
  ) is
  
  t_MultipleSecCount        number;
  t_RelationshipId          udt_Id;
  t_PendingLicenseTypeObjId udt_id;
  
  begin
    
    /*-- Get the count of the duplicate Secondary LTs
    select count(ltltc.LicenseTypeCategoryObjectId) - count(unique(ltltc.LicenseTypeCategoryObjectId))
      into t_MultipleSecCount
      from query.r_LicenseLicenseType llt
      join query.r_LicenseTypePendSecLTCat ltltc
        on ltltc.LicenseTypeJobId = llt.LicenseTypeJobId
     where llt.LicenseJobId = a_JobId;
     
    -- If the same Secondary LT exists on multiple Primary LTs
    If t_MultipleSecCount > 0 then
      -- Then raise an error
      api.pkg_Errors.RaiseError(-20000,
                                'You cannot have the same Secondary License Type on multiple License Types.');
    -- Else
    Else*/
      
      for llt in (select llt.licenseTypeJobid, llt.LicenseJobid, ltltc.licensetypecategoryobjectid, api.pkg_columnquery.value(llt.LicenseTypeJobId, 'LicenseTypeCode') LTCode
                  from query.r_LicenseLicenseType llt
                  join query.r_Licensetypeltcatprimary LTLTC on ltltc.LicenseTypeJobid = llt.licensetypejobid
                 where llt.LicenseJobId = a_JobId) loop
        -- Find the Primary License Type object related to the process otherwise create it.
        begin
          select applt.PendingLicenseTypeObjectId
            into t_PendingLicenseTypeObjId
            from query.r_addpermitlttopendlt applt
            join query.r_PendLTLicTypeCat pltltc on pltltc.PendingLicTypeObjID = applt.PendingLicenseTypeObjectId
            where applt.AddPermitLTProcessId = a_ObjectID
              and pltltc.LicenseTypeCategoryObjectId = llt.licensetypecategoryobjectid;
        exception when no_data_found then
          t_PendingLicenseTypeObjId := api.pkg_objectupdate.New(api.pkg_configquery.objectdefidforname('o_PendingLicenseType'));

          t_Relationshipid := api.pkg_relationshipupdate.new(api.pkg_ConfigQuery.EndPointIdForName('o_PendingLicenseType', 'PendLTLicTypeCatPrimary'), 
                                                               t_PendingLicenseTypeObjId, 
                                                               llt.LicenseTypeCategoryObjectId);
          t_Relationshipid := api.pkg_relationshipupdate.new(api.pkg_ConfigQuery.EndPointIdForName('p_AddPermitLTToLicense', 'PendLicType'), 
                                                               a_ObjectID, 
                                                               t_PendingLicenseTypeObjId);
        end;
                 
        -- Find all License Type Jobs related to License Job and their pending LTCs
        for c in (select ltltc.LicenseTypeCategoryObjectId, ltltc.LicenseTypeJobId, ltltc.RelationshipId, api.pkg_columnquery.value(llt.LicenseTypeJobId, 'LicenseTypeCode') LTCode
                    from query.r_LicenseTypePendSecLTCat ltltc
                   where ltltc.LicenseTypeJobId = llt.LicenseTypeJobId) loop

          Begin
            select r.RelationshipId
              into t_RelationshipId
              from api.Relationships r
             where r.ToObjectId = c.LicenseTypeCategoryObjectId
               and r.FromObjectId = t_PendingLicenseTypeObjId
               and r.EndPointId = api.pkg_ConfigQuery.EndPointIdForName('o_PendingLicenseType',
                                                                        'LicTypeCatPending')
               and api.pkg_columnquery.value(r.relationshipid, 'MasterLTCode') = c.LTCode;
          Exception When TOO_MANY_ROWS Then
            api.pkg_Errors.RaiseError(-20000,
                                      'You cannot have the same Secondary License Type on multiple Primary License Types. Please insure that you are creating only one Secondary '||
                                      api.pkg_ColumnQuery.Value(c.LicenseTypeCategoryObjectId, 'LicenseTypeCode')||'.');
          When NO_DATA_FOUND Then
            -- Relate Pending LTCs to Process
            t_RelationshipId := api.pkg_RelationshipUpdate.New(api.pkg_ConfigQuery.EndPointIdForName('o_PendingLicenseType', 'LicTypeCatPending'), 
                                                               t_PendingLicenseTypeObjId, 
                                                               c.LicenseTypeCategoryObjectId);
            -- Copy rel details from LT Pending rel to Add Permit/LT Pending rel
            pkg_copy.CopyStoredObjectDetails(c.RelationshipId, t_RelationshipId);
            
            -- Set GallonageRange and NumberOfMonthsLicensed details on the rel
            api.pkg_ColumnUpdate.SetValue(t_RelationshipId, 'GallonageRange', api.pkg_ColumnQuery.Value(c.LicenseTypeJobId,
                                                                                                        'GallonageRange'));
            api.pkg_ColumnUpdate.SetValue(t_RelationshipId, 'NumberOfMonthsLicensed', api.pkg_ColumnQuery.Value(c.LicenseTypeJobId,
                                                                                                                'NumberOfMonthsLicensed'));
            -- Set Master LT Code on rel to LicenseTypeCode from LT job
            api.pkg_ColumnUpdate.SetValue(t_RelationshipId, 'MasterLTCode', api.pkg_ColumnQuery.Value(c.LicenseTypeJobId,
                                                                                                      'LicenseTypeCode'));
            
            -- Set the RelationshipID on Duplicates.
            for c_dup in (select d.duplicateid objectid
                            from sitespecific.duplicate_t d 
                           where d.LicenseTypeJobID = c.licensetypejobid
                             and d.LicenseTypeCategoryObjectID = c.licensetypecategoryobjectid
                             and d.RelationshipID is null) loop
              api.pkg_columnupdate.SetValue(c_dup.objectid, 'RelationshipID', t_RelationshipId);
            end loop;
            
          When Others Then
            api.Pkg_Errors.RaiseError(-20000, SQLERRM);
          End;
        end loop;
      end loop;
    -- End If
    --End If;
  end;
  
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
    a_JobId             udt_Id
  ) is
  t_ActionRequested        varchar(50);
  t_PrimaryLTorSecondaryLT varchar(100);
  t_ChangeStatus           udt_Id;
  t_ProcessName            varchar(50);
  
  begin
      select pt.name
        into t_ProcessName
        from api.processes p
        join api.processtypes pt on pt.ProcessTypeId = p.ProcessTypeId
       where p.ProcessId = a_ProcessId;
      t_ActionRequested := api.pkg_columnquery.Value(a_ProcessId, 'ActionRequested');
      t_PrimaryLTorSecondaryLT := api.pkg_columnquery.Value(a_ProcessId, 'PrimaryLTOrSecondaryLT');
    
    IF (t_ActionRequested = 'CANCEL' or t_ActionRequested is null)
       and t_ProcessName = 'p_TerminateLicenseType'
       and (t_PrimaryLTorSecondaryLT = 'Primary License Type' or t_PrimaryLTorSecondaryLT is null)
    THEN
      t_ChangeStatus := api.pkg_processupdate.New(a_JobId, 
                                                  api.pkg_ConfigQuery.ObjectDefIdForName('p_ChangeStatus'), 
                                                  'System Generated.', 
                                                  NULL, 
                                                  NULL, 
                                                  NULL);
      api.pkg_processupdate.Complete(t_ChangeStatus, 'Canceled');  
      
      --Terminate Secondary License Types
      for c in (select slt.relationshipid, slt.Status, slt.LicenseTypeCount
                from query.r_licensetypeltcatsecondary slt 
               where slt.LicenseTypeJobId = a_JobId --License Type Jobid
                 and slt.status not in ('CANCELED', 'AUTO REVOKED', 'DENIED', 'DEPARTMENT REVOKED', 'NON-RENEWED', 'SLMS REVOKED', 'VOIDED', 'WITHDRAWN')) loop
      --Set Status to Cancelled
      api.pkg_columnupdate.SetValue(c.relationshipid, 'Status', 'CANCELED');
	  sitespecific.pkg_BatchType.SetBatchFlags(c.relationshipid); -- Sheik 11/21/2016 WO#8925 Unchecking secondary checkboxes from override area
    end loop;
    END IF;       
        
    IF (t_ActionRequested = 'SURRENDER - RULE 65' or t_ActionRequested = 'SURRENDER' or t_ActionRequested is null)
       and t_ProcessName = 'p_SurrenderLicenseType'
       and (t_PrimaryLTorSecondaryLT = 'Primary License Type' or t_PrimaryLTorSecondaryLT is null)
    THEN
      t_ChangeStatus := api.pkg_processupdate.New(a_JobId, 
                                                  api.pkg_ConfigQuery.ObjectDefIdForName('p_ChangeStatus'), 
                                                  'System Generated.', 
                                                  NULL, 
                                                  NULL, 
                                                  NULL);
      api.pkg_processupdate.Complete(t_ChangeStatus, 'Surrendered');
    END IF;         
      
    IF (t_ActionRequested = 'RE-ACTIVATE' or t_ActionRequested is null)
       and t_ProcessName = 'p_ReactivateLicenseType'
       and (t_PrimaryLTorSecondaryLT = 'Primary License Type' or t_PrimaryLTorSecondaryLT is null)
    THEN
      t_ChangeStatus := api.pkg_processupdate.New(a_JobId, 
                                                  api.pkg_ConfigQuery.ObjectDefIdForName('p_ChangeStatus'), 
                                                  'System Generated.', 
                                                  NULL, 
                                                  NULL, 
                                                  NULL);
      api.pkg_processupdate.Complete(t_ChangeStatus, 'Active');  
    END IF;

  end ChangeStatusForHQProcesses;
  
    /*---------------------------------------------------------------------------
   * IssueLicense
   *   This procedure will run as an activity on Issue License process and will
   * update the or create new Secondary License Types on the License Type job.
   *-------------------------------------------------------------------------*/
  procedure IssueLicense (
    a_ObjectId          udt_Id,
    a_AsOfDate          date,
    a_JobId             udt_Id
  ) is
  
  t_AddPermitLTId          udt_Id;
  t_LicenseTypeJobId       udt_Id;
  t_LicLicTypCatPriObjId   udt_Id;
  t_LicRelLTSecLTC         udt_Id;
  t_LTRelLTSecLTC          udt_Id;
  t_ReApply                varchar2(2);
  t_RelId                  udt_Id;
  t_NewProcId              udt_id;
  t_SecLTCatObjId          udt_id;
  
  begin
  
    -- Get AddPermit/LTProcessId
    t_AddPermitLTId := api.pkg_ColumnQuery.Value(a_ObjectId, 'AddPermitLTProcessId');
    
    -- Loop through License Type Jobs related to License
    For c_1 in (select -- Grab License Types (LT) associated with the Add Permit/LT
                       r1.ToObjectId LicTypeJobId,
                       r2.ToObjectId LTCObjId,
                       ltc.LicenseTypeCode,
                       api.pkg_columnquery.value(r2.fromobjectid, 'ReApply') reApply
                  from api.relationships r1
                  join api.relationships r2 on (r2.FromObjectId = r1.ToObjectId
                                           and r2.EndpointId = api.pkg_configquery.EndPointIdForName('j_LicenseType',
                                                                                                     'LicTypeCatPrimary'))
                  join query.o_LicenseTypeCategory ltc on (ltc.ObjectId = r2.ToObjectId)
                 where r1.FromObjectId = a_JobId -- License JobId
                   and r1.EndPointId = api.pkg_configquery.EndPointIdForName('j_License',
                                                                             'LicenseType')) loop
       
       -- Set t_LicenseTypeJobId to the c_1.LicTypeJobId
       t_LicenseTypeJobId := c_1.LicTypeJobId;
       
       --Change Status To pending if Re-Apply is checked
       if c_1.reApply = 'Y' then
         t_NewProcId := api.pkg_processupdate.New(c_1.LicTypeJobId, 
           api.pkg_configquery.ObjectDefIdForName('p_ChangeStatus'),
           '', null, null, null);
         api.pkg_processupdate.Complete(t_NewProcId, 'Active');
         api.pkg_columnupdate.setvalue(c_1.LicTypeJobid, 'ReApply', 'N');
       end if;
    
       -- Find License Type Category - Secondary from Pending LT rel on Add Permit/LT process
       -- Objective: Add any new Secondary License Types from the Add Permit/LT process to the License Type
       for c_2 in (-- Secondary License Types associated with Add Permit/LT process
                   select aplslt.RelationshipId PendSecLTRelId,
                          aplslt.LicenseTypeCategoryObjectId LTSecObjId,
                          aplslt.ReApply ReApply,
                          plt.LicenseTypeCode MasterLTCode
                     from query.r_addpermitlttopendlt aplt
                     join query.o_PendingLicenseType plt
                       on plt.ObjectId = aplt.PendingLicenseTypeObjectId
                     join query.r_AddPermitLTToLicPendLTC aplslt
                       on aplslt.PendingLicenseTypeObjId = plt.objectid
                    where aplt.AddPermitLTProcessId = t_AddPermitLTId
                      and aplslt.MasterLTCode = c_1.LicenseTypeCode
                      and plt.LicenseTypeCode = c_1.LicenseTypeCode
                   /*select ToObjectId LTSecObjId,
                          RelationshipId PendSecLTRelId
                     from api.relationships
                    where FromObjectId = t_AddPermitLTId --c_1.LicTypeJobId
                      and EndpointId = api.pkg_configquery.EndPointIdForName('p_AddPermitLTToLicense', --'j_LicenseType',
                                                                             'LicTypeCatPending')*/)loop

        -- Is this Secondary Already on the License?  If yes, then only update the Count detail.
         BEGIN                         
           select r1.ToObjectId,
                  r1.FromObjectId,
                  r1.RelationshipId 
             into t_LicLicTypCatPriObjId,
                  t_LicenseTypeJobId,
                  t_LicRelLTSecLTC           
             from api.relationships r1                               
             join api.relationships r2 on (r2.ToObjectId = r1.FromObjectId
                                      and r2.EndPointId = api.pkg_configquery.EndPointIdForName('j_License',
                                                                                                'LicenseType'))
           where r2.FromObjectId = a_JobId -- License JobId
           and r1.ToObjectId = c_2.LTSecObjId
           and api.pkg_columnquery.value(r1.fromobjectid, 'LicenseTypeCode') = c_2.MasterLTCode
           and r1.EndPointId = api.pkg_configquery.EndPointIdForName('j_LicenseType',
                                                                     'LicTypeCatSecondary');            
                                                       
           -- If the Re-Apply checkbox is selected then Change Status to Pending.
           if (c_2.ReApply = 'Y') then
              api.pkg_columnupdate.setvalue(c_2.PendSecLTRelId, 'Status', 'PENDING');
              api.pkg_columnupdate.setvalue(t_LicRelLTSecLTC, 'StatusDate', trunc(sysdate));
           end if;
           -- Copy License Type Count for the Secondary License Type
           pkg_copy.CopyStoredObjectDetails(c_2.PendSecLTRelId, t_LicRelLTSecLTC);
           --Update Duplicates
           for c_dup in (select d.duplicateid objectid
                           from sitespecific.duplicate_t d 
                          where d.LicenseTypeJobID = t_LicenseTypeJobId
                            and d.LicenseTypeCategoryObjectID = c_2.LTSecObjId
                            and d.RelationshipID = c_2.PendSecLTRelId) loop
             api.pkg_columnupdate.SetValue(c_dup.objectid, 'RelationshipID', t_LicRelLTSecLTC);
             api.pkg_columnupdate.SetValue(c_dup.objectid, 'IssueDate', sysdate);
           end loop;

         EXCEPTION WHEN NO_DATA_FOUND THEN
               -- Relate this Secondary License Type to the Existing License Type job related to the License
               t_RelId := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName('j_LicenseType',
                                                                                               'LicTypeCatSecondary'),
                                                         t_LicenseTypeJobId,
                                                         c_2.LTSecObjId);
                            
               -- Copy License Type Count for the Secondary License Type                 
               pkg_copy.CopyStoredObjectDetails(c_2.PendSecLTRelId,
                                                t_RelId);
               -- Set the Secondary LT Status Date to sysdate
               api.pkg_ColumnUpdate.SetValue(t_RelId,
                                             'StatusDate',
                                             sysdate);
               --Update Duplicates
               for c_dup in (select d.duplicateid objectid
                               from sitespecific.duplicate_t d 
                              where d.LicenseTypeJobID = t_LicenseTypeJobId
                                and d.LicenseTypeCategoryObjectID = c_2.LTSecObjId
                                and d.RelationshipID = c_2.PendSecLTRelId) loop
                 api.pkg_columnupdate.SetValue(c_dup.objectid, 'RelationshipID', t_RelId);
                 api.pkg_columnupdate.SetValue(c_dup.objectid, 'IssueDate', sysdate);
               end loop;

         WHEN OTHERS THEN
            api.pkg_Errors.RaiseError(-20000,
                                      'ERROR relating Secondary LT with Existing License Type: '||api.pkg_ColumnQuery.Value(t_LicenseTypeJobId,
                                                                                                                            'LicenseTypeCode')||SQLERRM);
         END;
       end loop; -- c  Secondaries on the Add Permit/LT process being added to existing License Type
    End Loop;
    
    -- Loop through License Type Jobs related to License
    For c_3 in (select -- Grab License Types (LT) associated with the Add Permit/LT
                       r1.ToObjectId LicTypeJobId,
                       r2.ToObjectId LTCObjId,
                       api.pkg_columnquery.value(r1.toobjectid, 'LicenseTypeCode') LTCode,
                       api.pkg_columnquery.value(r2.fromobjectid, 'ReApply') reApply
                  from api.relationships r1
                  join api.relationships r2 on (r2.FromObjectId = r1.ToObjectId
                                           and r2.EndpointId = api.pkg_configquery.EndPointIdForName('j_LicenseType',
                                                                                                     'LicTypeCatPrimary'))
                  join query.o_licensetypecategory ltc on (ltc.ObjectId = r2.ToObjectId)
                 where r1.FromObjectId = a_JobId -- License JobId
                   and r1.EndPointId = api.pkg_configquery.EndPointIdForName('j_License',
                                                                             'LicenseType')) loop
      
      --Change Status To pending if Re-Apply is checked
      if c_3.reApply = 'Y' then
        t_NewProcId := api.pkg_processupdate.New(c_3.LicTypeJobId, 
          api.pkg_configquery.ObjectDefIdForName('p_ChangeStatus'),
          '', null, null, null);
        api.pkg_processupdate.Complete(t_NewProcId, 'Pending');
        api.pkg_columnupdate.setvalue(c_3.LicTypeJobid, 'ReApply', 'N');
      end if;
      
      -- Now evaluate this License Type on the License for any Secondaries.
      -- Each Secondary on the License must be on Add Permit/LT process; otherwise remove it from License Type.
      -- Update License Type Count for the Secondary, if Secondary is to remain on License Type.
             
       for c_4 in (select r1.ToObjectId LTCSecObjId,
                          r1.FromObjectId LTJobId,
                          r1.RelationshipId SecRelId
                     from api.relationships r1
                    where r1.FromObjectId = c_3.LicTypeJobId -- License Type JobId 
                      and r1.EndPointId = api.pkg_configquery.EndPointIdForName('j_LicenseType',
                                                                                'LicTypeCatSecondary'))loop
               
         BEGIN-- Is this Secondary on the Add Permit/LT process?  If not, remove it from License Type
               
        /* select ltcs.RelationshipId, ltps.ReApply, ltcs.LicenseTypeCategoryObjectId
           into t_LTRelLTSecLTC, t_ReApply, t_SecLTCatObjId
           from query.p_Addpermitlttolicense aplt
           join query.r_LicenseLicenseType llt on llt.LicenseJobId = aplt.JobId
           join query.r_LicenseTypePendSecLTCat ltps on ltps.LicenseTypeJobId = llt.LicenseTypeJobId
           --join query.o_licensetypecategory ltc on ltc.ObjectId = ltps.LicenseTypeCategoryObjectId
           join query.r_LicenseTypeLTCatSecondary ltcs on ltcs.LicenseTypeCategoryObjectId = ltps.LicenseTypeCategoryObjectId
                                                      and ltcs.LicenseTypeJobId = llt.LicenseTypeJobId
          where aplt.ObjectId = t_AddPermitLTId
            and api.pkg_columnquery.value(ltcs.LicenseTypeCategoryObjectId, 'LicenseTypeCode')= c_3.LTCode;*/
            --Find pending licene types
              
           select r2.RelationshipId
                  , api.pkg_columnquery.value(r2.RelationshipId, 'ReApply')
             into t_LTRelLTSecLTC, t_ReApply
             from api.relationships r1
             join api.relationships r2 on r2.fromobjectid = r1.toobjectid
            where r1.FromObjectId = t_AddPermitLTId --c_4.LTJobId
              and r2.ToObjectId = c_4.LTCSecObjId
              and api.pkg_columnquery.value(r1.ToObjectId, 'LicenseTypeCode')= c_3.LTCode
              and r1.EndpointId = api.pkg_configquery.EndPointIdForName('p_AddPermitLTToLicense', --'j_LicenseType',
                                                                        'PendLicType')
              and r2.EndpointId = api.pkg_configquery.EndPointIdForName('o_PendingLicenseType', --'j_LicenseType',
                                                                        'LicTypeCatPending');
           
           -- If the Re-Apply checkbox is selected then Change Status to Pending.
           if (t_ReApply = 'Y') then
              api.pkg_columnupdate.setvalue(t_LTRelLTSecLTC, 'Status', 'PENDING');
           end if;
           
           -- Copy License Type Count for the Secondary License Type, in case the count was changed by the Application
           pkg_copy.CopyStoredObjectDetails(t_LTRelLTSecLTC, c_4.SecRelId);
                 
           for c_dup in (select d.duplicateid objectid
                           from sitespecific.duplicate_t d 
                          where d.LicenseTypeJobID = c_3.Lictypejobid
                            and d.LicenseTypeCategoryObjectID = t_SecLTCatObjId
                            and d.RelationshipID = t_LTRelLTSecLTC) loop
             api.pkg_columnupdate.SetValue(c_dup.objectid, 'RelationshipID', t_LTRelLTSecLTC);
             --api.pkg_columnupdate.SetValue(c_dup.objectid, 'IssueDate', sysdate);
           end loop;

         EXCEPTION WHEN NO_DATA_FOUND THEN -- Remove Relationship to this Secondary License Type
         
           api.pkg_relationshipupdate.Remove(c_4.SecRelId);       

         WHEN OTHERS THEN
            api.pkg_Errors.RaiseError(-20000, 'ERROR removing Secondary License Type: ' || SQLERRM);
         END;
       end loop; -- c_4 Existing Secondaries on License Type
     End Loop;

  end IssueLicense;

  /*--------------------------------------------------
  *  TerminateLicense() -- PUBLIC
  *
  *  This procedure terminates a License when all related LT are in the status of cancelled.
  *  It will put the License in the status of Non-Renewed under the same circumstances if
  *  one of the LTs are in a Non-Renewed status.
  *-------------------------------------------------*/
  procedure TerminateLicense(a_ProcessId udt_Id, a_AsOfDate date) is
  
    t_LicenseJobId              udt_Id;
    t_TerminateLicenseDefId     udt_Id;
    t_ChangeStatusDefId         udt_Id;
    t_ChangeStatusProcessId     udt_Id;
    t_TerminateLicenseProcessId udt_Id;
    t_LicenseTypeJobId          udt_Id;
    t_CountofLicTypes           number;
    t_CountofNRENLicTypes       number;
    
  begin
 
    t_LicenseTypeJobId         := api.pkg_columnquery.NumericValue(a_ProcessId, 'JobId');
    t_LicenseJobId             := api.pkg_columnquery.Value(t_LicenseTypeJobId, 'LicenseJobId');
    t_TerminateLicenseDefId    := api.pkg_configquery.ObjectDefIdForName('p_TerminateLicense');
    t_ChangeStatusDefId        := api.pkg_configquery.ObjectDefIdForName('p_ChangeStatus');
    
    if api.pkg_columnquery.Value(t_LicenseJobId, 'StatusName') in ('ACTIVE', 'SUSPEN', 'PEND') then
    

      select count(llt.LicenseTypeJobId)
        into t_CountofLicTypes
        from query.r_licenselicensetype llt
        join query.j_licensetype lt on lt.JobId = llt.LicenseTypeJobId
        where llt.LicenseJobId = t_LicenseJobId
         and lt.StatusName in ('ACTIVE', 'SUREND', 'PEND', 'REVPEN')
         and lt.JobId != t_LicenseTypeJobId;    
      if t_CountofLicTypes = 0 then

      --check to see if the license should be set to Non-Renewed or Cancel
       select count(llt.LicenseTypeJobId)
        into t_CountofNRENLicTypes
        from query.r_licenselicensetype llt
        join query.j_licensetype lt on lt.JobId = llt.LicenseTypeJobId
        where llt.LicenseJobId = t_LicenseJobId
         and lt.StatusName in ('NREN');
      
        if t_CountofNRENLicTypes > 0 then
          t_ChangeStatusProcessId := api.pkg_processupdate.New(t_LicenseJobId,
                                                                    t_ChangeStatusDefId,
                                                                    'SYSTEM GENERATED.',
                                                                    NULL,
                                                                    NULL,
                                                                    NULL);
            api.pkg_processupdate.Complete(t_ChangeStatusProcessId, 'Non-Renewed');
        else
          t_TerminateLicenseProcessId := api.pkg_processupdate.New(t_LicenseJobId,
                                                                    t_TerminateLicenseDefId,
                                                                    NULL,
                                                                    NULL,
                                                                    NULL,
                                                                    NULL);
            api.pkg_processupdate.Complete(t_TerminateLicenseProcessId, 'Cancel');
        end if;
      end if;
    end if;
    
  end TerminateLicense;
  
/*----------------------------------------------------------------------------------------------
  --  FillUnissueLTGrid()     --Public 
  --  Populates the License Types grid on the UnIssue License Type process.
  ----------------------------------------------------------------------------------------------*/ 
  procedure FillUnissueLTGrid(
      a_ObjectId udt_Id,
      a_AsOfDate date
    ) is
      t_Jobid         udt_Id := api.pkg_columnquery.value(a_ObjectId, 'Jobid');
      t_JobTypeName   varchar2(30) := api.pkg_columnquery.Value(t_Jobid, 'ObjectDefName'); 
      t_ObjectDefName varchar2(30) := api.pkg_columnquery.Value(a_ObjectId, 'ObjectDefName');                       
      t_NewRELId      udt_id;
  begin  
    for c in (select re.ToObjectId ToObjectId,
                     api.pkg_columnquery.value(re.RelationshipId, 'Status') Status,
                     api.pkg_columnquery.value(re.RelationshipId, 'MasterLTCode') MasterLTCode,
                     api.pkg_columnquery.value(re.RelationshipId, 'LicenseTypeCount') LicenseTypeCount                    
                from api.relationships re
               where re.FromObjectId = t_Jobid
                 and re.EndPointId = api.pkg_configquery.EndPointIdForName(t_JobTypeName, 'LicTypeCatSecondary')
             ) loop
      if c.Status in ('ACTIVE', 'PENDING') then
        t_NewRELId := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName(t_ObjectDefName, 'SecondaryLicenseType'),
                                                     a_Objectid, 
                                                     c.ToObjectid);

        api.pkg_columnupdate.SetValue(t_NewRELId, 'Status', c.Status);
        api.pkg_columnupdate.SetValue(t_NewRELId, 'MasterLTCode', c.MasterLTCode);
        api.pkg_columnupdate.SetValue(t_NewRELId, 'LicenseTypeCount', c.LicenseTypeCount);
      end if;
    end loop;
  end FillUnissueLTGrid;
  
/*----------------------------------------------------------------------------------------------
  --  LicenseTypesToUnissue()     --Private
  --  Finds the License Types that were selected to unissue
  ----------------------------------------------------------------------------------------------*/ 
  function LicenseTypesToUnissue(
      a_ProcessId            udt_Id,
      a_PrimaryOrSecondary   varchar2
    ) return udt_IdList is
    t_LicenseTypes           udt_IdList;
    t_JobId                  udt_Id := api.pkg_ColumnQuery.Value(a_ProcessId, 'JobId');
  begin
    -- Find all license types that are available to be canceled on this LT job
    for c in (select slt.RelationshipId,
                     (select UnIssue
                        from query.r_SecondaryLTToUnissue
                       where UnIssueLTProcessId = a_ProcessId
                         and SecondaryLicenseTypeObjectId = slt.LicenseTypeCategoryObjectId) UnIssue
                from api.jobs jo 
                join api.jobstatuses ltjs on ltjs.StatusId = jo.StatusId 
                                         and ltjs.JobTypeId = jo.JobTypeId
                join query.r_LicenseTypeLTCatSecondary slt on slt.LicenseTypeJobId = jo.JobId
                join api.statuses sltst on upper(sltst.Description) = upper(slt.Status)
                join api.JobStatuses sltjs on sltjs.JobTypeId = jo.JobTypeId
                                          and sltjs.StatusId = sltst.StatusId
               where jo.JobId = t_JobId
                 and ltjs.StatusType in ('O', 'I')
                 and sltjs.StatusType in ('O', 'I')) loop -- Limit to all intermediate status types
      if c.RelationshipId is not null and (a_PrimaryOrSecondary = 'Primary License Type' or c.UnIssue = 'Y') then
        t_LicenseTypes(t_LicenseTypes.Count + 1) := c.RelationshipId;
      end if;
    end loop;
    
    return t_LicenseTypes;
  end;
  
/*----------------------------------------------------------------------------------------------
  --  CheckRenewal()     --Private
  --  Finds the License Types that were selected to unissue
  ----------------------------------------------------------------------------------------------*/ 
  function IsLicenseTypeRenewed(
      a_ObjectId             udt_Id,
      a_IsSeasonal           boolean,
      a_SeasonalStartDate    date
    ) return boolean is
    t_IsChangeApp               boolean;
    t_IssueDate                 date;
    t_ReadyToIssueDate          date;
    t_EffectiveDate             date;
  begin
    t_ReadyToIssueDate := trunc(api.pkg_ColumnQuery.DateValue(a_ObjectId, 'ReadytoIssueDate'));
    t_IsChangeApp := api.pkg_ColumnQuery.Value(a_ObjectId, 'IncludeInChangeAppBatch') = 'Y';
    t_IssueDate := trunc(api.pkg_ColumnQuery.DateValue(a_ObjectId, 'IssueDate'));
      
    -- First, look at Seasonal Licenses
    if a_IsSeasonal then 
      if t_IsChangeApp then
        t_EffectiveDate := greatest(a_SeasonalStartDate, t_ReadyToIssueDate);
      else
        t_EffectiveDate := a_SeasonalStartDate;
      end if;
    -- Next, look at Changed but not Seasonal Apps/Licenses
    elsif t_IsChangeApp then
      t_EffectiveDate := t_ReadyToIssueDate;
    else
      t_EffectiveDate := greatest(nvl(t_IssueDate, to_date('12/31/3999', 'MM/DD/YYYY')), nvl(t_ReadyToIssueDate, to_date('12/31/3999', 'MM/DD/YYYY')));
    end if;
      
    -- Return whether renewed or not
    if t_IssueDate < t_EffectiveDate then
      return true;
    else
      return false;
    end if;
  end;
  
/*----------------------------------------------------------------------------------------------
  --  UnissueLicenseType()     --Public 
  --  Unissues the License
  ----------------------------------------------------------------------------------------------*/ 
  procedure UnissueLicenseType(
      a_ObjectId             udt_Id,
      a_AsOfDate             date,
      a_PrimaryOrSecondary   varchar2
    ) is
    t_JobId                     udt_Id := api.pkg_ColumnQuery.Value(a_ObjectId, 'JobId');
    t_ApplicationJobId          udt_Id;
    t_LicenseJobId              udt_Id;
    t_PrimaryLTObjectId         udt_Id;
    t_SecondaryLTObjectId       udt_Id;
    t_ChangeStatusProcessId     udt_Id;
    t_NewPaymentStatusObjectId  udt_Id;
    t_PayTransPayStatRelId      udt_Id;
    t_PaymentStatusDefId        udt_Id := api.pkg_objectdefquery.IdForName('o_PaymentStatus');
    t_PayTransPayStatEndpoint   udt_Id := api.pkg_configquery.EndPointIdForName('o_PaymentTransactions', 'PaymentStatus');
    t_ChangeStatusProcessTypeId udt_Id := api.pkg_configquery.ObjectDefIdForName('p_ChangeStatus');
    t_IssueLicenseProcessTypeId udt_Id := api.pkg_configquery.ObjectDefIdForName('p_IssueLicense');
    t_IssueLTProcessTypeId      udt_Id := api.pkg_ConfigQuery.ObjectDefIdForName('p_IssueLicenseType');
    t_IssueLicenseProcessId     udt_Id;
    t_SecLicenseTypesToUnIssue  udt_IdList;    
    t_SecLicenseTypeCode        varchar2(2);
    t_PreviousStatus            varchar2(100);
    t_LicTypeStatus             varchar2(100);
    t_IsActive                  varchar(1) := 'N';
    t_IssueLicenseCount         number;
    t_EarnedAmount              number(11, 2);
    t_IsSeasonal                boolean;
    t_SeasonalStartDate         date;
    t_ApplicationSLTUnissued    boolean := false;
    t_PayTransObjectDefId       udt_id := api.Pkg_Configquery.ObjectDefIdForName('o_PaymentTransactions');
  begin
    t_SecLicenseTypestoUnIssue := LicenseTypesToUnissue(a_ObjectId, a_PrimaryOrSecondary);
    
    -- Raise Error if the Primary License Type is not active or no secondaries selected
    select max('Y')
      into t_IsActive
      from api.jobs jo 
      join api.jobstatuses ltjs on ltjs.StatusId = jo.StatusId
                               and ltjs.JobTypeId = jo.JobTypeId
     where jo.JobId = t_JobId
       and ltjs.StatusType in ('O', 'I');
       
    if t_IsActive != 'Y' then
      api.pkg_Errors.RaiseError(-20000, 'Error Unissuing License Type: Primary License Type is not active.');
    end if;
    
    if  t_SecLicenseTypesToUnIssue.Count = 0 and a_PrimaryOrSecondary = 'Secondary License Type' then
      api.pkg_Errors.RaiseError(-20000, 'Error Unissuing License Type: No Secondary License Types were selected.');
    end if;
    
    -- Find Application Job for later use
    select max(al.ApplicationJobId),
           max(llt.LicenseJobId)
      into t_ApplicationJobId,
           t_LicenseJobId
      from query.j_Licensetype lt
      join query.r_LicenseLicenseType llt on llt.LicenseTypeJobId = lt.JobId 
      join query.r_ApplicationLicense al on al.LicenseJobId = llt.LicenseJobId
     where lt.JobId = t_JobId;
          
    if t_ApplicationJobId is null  or t_LicenseJobId is null then 
      api.pkg_Errors.RaiseError(-20000, 'Error Unissuing License Type: Could not determine application or license being unissued.');
    end if;
          
    -- Get the Seasonal Date - Seasonal is always on Primary LT
    t_IsSeasonal := api.pkg_ColumnQuery.Value(t_JobId, 'SeasonalStartMonthNumber') is not null;
    t_SeasonalStartDate := to_date(lpad(nvl(api.pkg_ColumnQuery.Value(t_JobId, 'SeasonalStartMonthNumber'), '01'),2,'00') || '/01/' || nvl(api.pkg_ColumnQuery.Value(t_JobId, 'ExpiringYear'),'9999'), 'MM/DD/YYYY');
    
    
    -- Check Primary License Types being unissued to see if they have been renewed  - Raise Error if renewed
    if IsLicenseTypeRenewed(t_JobId, t_IsSeasonal, t_SeasonalStartDate) then
      api.pkg_Errors.RaiseError(-20000, 'Error Unissuing License Type: Renewed Licenses cannot be unissued.');
    end if;
    
    -- Check all Secondary License Types being unissued to see if they have been renewed  - Raise Error if renewed
    for i in 1..t_SecLicenseTypesToUnIssue.Count loop
      -- Raise an error if renewed license
      if IsLicenseTypeRenewed(t_SecLicenseTypesToUnIssue(i), t_IsSeasonal, t_SeasonalStartDate) then
        api.pkg_Errors.RaiseError(-20000, 'Error Unissuing License Type: Renewed Licenses cannot be unissued.');
      end if;
    end loop;
     
    -- Process all Secondary License Types    
    for i in 1..t_SecLicenseTypesToUnIssue.Count loop
      -- Set this license type to pending
      api.pkg_ColumnUpdate.SetValue(t_SecLicenseTypesToUnIssue(i), 'Status', 'PENDING');
              
      begin
        -- Set the SLT from the Application job to Pending that matches the SLT to Unissue
        select slt.RelationshipId
          into t_SecondaryLTObjectId
          from query.r_AppPrimaryLicenseType aplt
          join query.o_primarylicensetype plt on aplt.LicenseTypeObjectId = plt.ObjectId
          join query.r_priltltcatsecondary slt on slt.PrimaryLicenseTypeObjectId = plt.ObjectId
          join query.o_LicenseTypeCategory ltc on ltc.ObjectId = slt.LicenseTypeCategoryObjectId
         where aplt.ApplicationObjectId = t_ApplicationJobId
           and plt.LicenseTypeCode = api.pkg_ColumnQuery.Value(t_JobId, 'LicenseTypeCode')
           and ltc.ObjectId = (select LicenseTypeCategoryObjectId
                                 from query.r_LicenseTypeLTCatSecondary
                                where RelationshipId = t_SecLicenseTypesToUnIssue(i));
        api.pkg_ColumnUpdate.SetValue(t_SecondaryLTObjectId, 'SStatus', 'PENDING');           
        api.pkg_ColumnUpdate.RemoveValue(t_SecondaryLTObjectId, 'Issued');       
        t_ApplicationSLTUnissued := true;
      exception when others then        
        -- Create Issue License Process
        select count(*)
          into t_IssueLicenseCount
          from api.Processes
         where ProcessTypeId = t_IssueLTProcessTypeId
           and JobId = t_JobId
           and Outcome is null;
             
        if a_PrimaryOrSecondary = 'Primary License Type' and t_IssueLicenseCount = 0 then
          t_IssueLicenseProcessId := api.pkg_ProcessUpdate.New(t_JobId, t_IssueLTProcessTypeId, null, null, null, null);
        end if;
      end;      
      
      select api.pkg_ColumnQuery.Value(LicenseTypeCategoryObjectId, 'LicenseTypeCode')
        into t_SecLicenseTypeCode
        from query.r_LicenseTypeLTCatSecondary
       where RelationshipId = t_SecLicenseTypesToUnIssue(i);
                        
      -- Unearn Fees for this SLT
      for j in (select reo.ObjectId                       
                  from api.fees fe
                  join sitespecific.feeschedule_t fs on fs.objectid = Sitespecific.pkg_fees.GetLicFeeSchedulObjId(fe.feeid)
                  join api.feetransactions ft on ft.FeeId = fe.FeeId
                  join api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                    on reo.LinkValue = to_char(ft.TransactionId)
                   and reo.ObjectDefId = t_PayTransObjectDefId
                 where fe.JobId in (t_ApplicationJobId, t_LicenseJobId, t_JobId)
                   and api.pkg_columnquery.Value(fs.objectid, 'EarnedOn') = 'LICENSE ISSUANCE'
                   and api.pkg_columnquery.Value(reo.objectid, 'PaymentStatus') is not null -- This payment has been earned
                   and fs.licensetypecode = t_SecLicenseTypeCode) loop
        
        select sum(ps.EarnedAmount) -- 06/03/2020 TJL  21754
          into t_EarnedAmount
          from query.o_PaymentTransactions pt 
          join query.r_PaymentStatusPaymentTrans pspt on pspt.PaymentTransactionObjectId = pt.ObjectId
          join query.o_PaymentStatus ps on ps.ObjectId = pspt.PaymentStatusObjectId
         where pt.objectid = j.ObjectId;
        if t_EarnedAmount < 0 then 
          t_NewPaymentStatusObjectId := api.pkg_objectupdate.New(t_PaymentStatusDefId);
          t_PayTransPayStatRelId     := api.pkg_relationshipupdate.New(t_PayTransPayStatEndpoint, j.Objectid, t_NewPaymentStatusObjectId);
          api.pkg_columnupdate.SetValue(t_NewPaymentStatusObjectId, 'Status', 'UNEARNED');
          api.pkg_columnupdate.SetValue(t_NewPaymentStatusObjectId, 'StatusDate', trunc(sysdate));
          api.pkg_columnupdate.SetValue(t_NewPaymentStatusObjectId, 'SystemGenerated', 'Y');
          api.pkg_columnupdate.setvalue(t_NewPaymentStatusObjectId, 'EarnedAmount', -t_EarnedAmount);
        end if;
      end loop;
      
      -- Set the SLT that was transferred back to Previous Status
      for j in (select slt.RelationshipId,
                       slt.StatusDate,
                       lt.StatusId,
                       lt.jobTypeId,
                       lt.ExpirationDate
                  from query.j_application app
                  join query.r_applicationlicensetransfer alt on alt.AppTransferredToObjectId = app.JobId
                  join query.r_AppPrimaryLicenseType aplt on aplt.ApplicationObjectId = app.JobId
                  join query.o_PrimaryLicenseType plt on plt.ObjectId = aplt.LicenseTypeObjectId
                  join query.r_PriLTLTCatSecondary pslt on pslt.PrimaryLicenseTypeObjectId = plt.ObjectId
                  join query.o_LicenseTypeCategory sltc on sltc.ObjectId = pslt.LicenseTypeCategoryObjectId 
                  join query.r_TransFromLTToPLT ltplt on ltplt.PrimaryLicenseTypeObjectId = plt.ObjectId
                  join query.j_Licensetype lt on lt.JobId = ltplt.LicenseTypeJobId
                  join query.r_LicenseTypeLTCatSecondary slt on slt.LicenseTypeJobId = lt.jobId
                  join query.o_LicenseTypeCategory ltc on ltc.ObjectId = slt.LicenseTypeCategoryObjectId and ltc.LicenseTypeCode = sltc.LicenseTypeCode
                  join api.Statuses st on upper(st.Description) = slt.Status
                  join api.JobStatuses js on js.StatusId = st.StatusId and js.JobTypeId = lt.JobTypeId
                 where app.JobId = t_ApplicationJobId
                   and pslt.IsTransferred = 'Y'
                   and js.StatusType in ('C', 'X')
                   and ltc.LicenseTypeCode = t_SecLicenseTypeCode) loop
        
        -- Had to do it this way because of an Oracle bug when I put it as a subselect above :(
        select js.StatusType
          into t_LicTypeStatus
          from api.Jobstatuses js
         where JobTypeId = j.JobTypeId
           and StatusId = j.StatusId;
        
        if (t_LicTypeStatus = 'X' or t_LicTypeStatus = 'C') and a_PrimaryOrSecondary = 'Secondary License Type' then
          api.pkg_Errors.RaiseError(-20000, 'Error Unissuing License Type: Cannot have an Active secondary on an inactive Primary on the transferor license type.');
        end if;
           
        select st.Description
          into t_PreviousStatus
          from sltstatuschange_t sc
          join api.statuses st on st.Tag = sc.StatusName 
         where sc.RelationshipId = j.RelationshipId
           and sc.EffectiveEndDate = (select max(effectiveenddate)
                                        from sitespecific.sltstatuschange_t
                                       where RelationshipId = sc.RelationshipId );       
        
        api.pkg_ColumnUpdate.SetValue(j.RelationshipId, 'Status', upper(t_PreviousStatus));
        
        -- Set batch flag back to what it should be
        for k in (select *
                    from (select BatchType,
                                 max(ExpirationDate) ExpirationDate
                            from query.j_LicenseBatch lb
                           where BatchType in ('1ST RENEWAL NOTICES', '2ND RENEWAL NOTICES', 'FINAL REVOCATION PENDING LETTERS', 'AUTO REVOKE LICENSE TYPES')
                           group by BatchType
                           order by decode(BatchType, '1ST RENEWAL NOTICES', 1, '2ND RENEWAL NOTICES', 2, 'FINAL REVOCATION PENDING LETTERS', 3, 'AUTO REVOKE LICENSE TYPES', 4))
                   where ExpirationDate < j.ExpirationDate
                     and rownum = 1) loop
            if k.BatchType = '1ST RENEWAL NOTICES' then
              pkg_BatchType.SetBatchFlags(j.RelationshipId, a_IncludeIn1stRenewal => 'Y');
            elsif k.BatchType = '2ND RENEWAL NOTICES' then
              pkg_BatchType.SetBatchFlags(j.RelationshipId, a_IncludeIn2ndRenewal => 'Y');
            elsif k.BatchType = 'FINAL REVOCATION PENDING LETTERS' then
              pkg_BatchType.SetBatchFlags(j.RelationshipId, a_IncludeInFinalRevPending => 'Y');
            elsif k.BatchType = 'AUTO REVOKE LICENSE TYPES' then
              pkg_BatchType.SetBatchFlags(j.RelationshipId, a_IncludeInRevokeBatch => 'Y');
            end if; 
        end loop;
      end loop;
      
      -- Remove Batch Flags, Ready To Issue Date, Issue Date on SLT      
      pkg_BatchType.SetBatchFlags(t_SecLicenseTypesToUnIssue(i)); -- Set all Flags to 'N'
      
      api.pkg_ColumnUpdate.RemoveValue(t_SecLicenseTypesToUnIssue(i), 'ReadyToIssueDate');
      api.pkg_ColumnUpdate.RemoveValue(t_SecLicenseTypesToUnIssue(i), 'IssueDate');      

    end loop;
    
    -- Set Application to Pending
    if a_PrimaryOrSecondary = 'Primary License Type' or t_ApplicationSLTUnissued then -- Only change status on application if something changed on app 
      t_ChangeStatusProcessId := api.pkg_Processupdate.New(t_ApplicationJobId, t_ChangeStatusProcessTypeId, 'Unissue License', null, null, null);
      api.pkg_processupdate.Complete(t_ChangeStatusProcessId, 'Pending');
        
      -- Create Issue License Process
      select count(*)
        into t_IssueLicenseCount
        from api.Processes
       where ProcessTypeId = t_IssueLicenseProcessTypeId
         and JobId = t_ApplicationJobId
         and Outcome is null;
      
      if t_IssueLicenseCount = 0 then
        t_IssueLicenseProcessId := api.pkg_ProcessUpdate.New(t_ApplicationJobId, t_IssueLicenseProcessTypeId, null, null, null, null);
      end if;
    end if;
    
    -- Process the Primary License Type
    if a_PrimaryOrSecondary = 'Primary License Type' then
      -- Unearn Fees for the LT
      for j in (select reo.ObjectId                       
                  from api.fees fe
                  join sitespecific.feeschedule_t fs on fs.objectid = Sitespecific.pkg_fees.GetLicFeeSchedulObjId(fe.feeid)
                  join api.feetransactions ft on ft.FeeId = fe.FeeId
                  join api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                    on reo.LinkValue = to_char(ft.TransactionId)
                   and reo.ObjectDefId = t_PayTransObjectDefId
                 where fe.JobId in (t_ApplicationJobId, t_LicenseJobId, t_JobId)
                   and api.pkg_columnquery.Value(fs.objectid, 'EarnedOn') = 'LICENSE ISSUANCE'
                   and api.pkg_columnquery.Value(reo.objectid, 'PaymentStatus') is not null -- This payment has been earned
                   and fs.licensetypecode = api.pkg_ColumnQuery.Value(t_JobId, 'LicenseTypeCode')) loop
        
        select sum(ps.EarnedAmount)     -- 06/03/2020 TJL  21754
          into t_EarnedAmount
          from query.o_PaymentTransactions pt 
          join query.r_PaymentStatusPaymentTrans pspt on pspt.PaymentTransactionObjectId = pt.ObjectId
          join query.o_PaymentStatus ps on ps.ObjectId = pspt.PaymentStatusObjectId
         where pt.objectid = j.ObjectId;
        if t_EarnedAmount < 0 then 
          t_NewPaymentStatusObjectId := api.pkg_objectupdate.New(t_PaymentStatusDefId);
          t_PayTransPayStatRelId     := api.pkg_relationshipupdate.New(t_PayTransPayStatEndpoint, j.Objectid, t_NewPaymentStatusObjectId);
          api.pkg_columnupdate.SetValue(t_NewPaymentStatusObjectId, 'Status', 'UNEARNED');
          api.pkg_columnupdate.SetValue(t_NewPaymentStatusObjectId, 'StatusDate', trunc(sysdate));
          api.pkg_columnupdate.SetValue(t_NewPaymentStatusObjectId, 'SystemGenerated', 'Y');
          api.pkg_columnupdate.setvalue(t_NewPaymentStatusObjectId, 'EarnedAmount', -t_EarnedAmount);
        end if;
      end loop;
      
      -- Set Status to Pending on LT
      t_ChangeStatusProcessId := api.pkg_Processupdate.New(t_JobId, t_ChangeStatusProcessTypeId, 'Unissue License', null, null, null);
      api.pkg_processupdate.Complete(t_ChangeStatusProcessId, 'Pending');
      
      -- Set Status to Pending on PLT
       begin
        -- Set the SLT from the Application job to Pending that matches the SLT to Unissue
        select plt.ObjectId
          into t_PrimaryLTObjectId
          from query.r_AppPrimaryLicenseType aplt
          join query.o_primarylicensetype plt on aplt.LicenseTypeObjectId = plt.ObjectId
         where aplt.ApplicationObjectId = t_ApplicationJobId
           and plt.LicenseTypeCode = api.pkg_ColumnQuery.Value(t_JobId, 'LicenseTypeCode');
        api.pkg_ColumnUpdate.SetValue(t_PrimaryLTObjectId, 'Status', 'PENDING');           
        api.pkg_ColumnUpdate.RemoveValue(t_PrimaryLTObjectId, 'Issued');      
      exception when others then        
        api.pkg_Errors.RaiseError(-20000, 'Error Unissuing Primary License Type on Application.');
      end;      
      
      -- Remove Expiration Date, Batch Flags, Ready To Issue Date, Issue Date on LT
      api.pkg_ColumnUpdate.RemoveValue(t_JobId, 'ExpiringMonth');
      api.pkg_ColumnUpdate.RemoveValue(t_JobId, 'ExpiringYear');
            
      pkg_BatchType.SetBatchFlags(t_JobId); -- Set all Flags to 'N'
      
      api.pkg_ColumnUpdate.RemoveValue(t_JobId, 'ReadyToIssueDate');
      api.pkg_ColumnUpdate.RemoveValue(t_JobId, 'IssueDate');
      
      api.pkg_ColumnUpdate.RemoveValue(t_LicenseJobId, 'IssueDate');

      -- Set Transferred License Type back to previous status
      for j in (select lt.JobId LTTransferredJobId,
                       lt.ExpirationDate,
                       lt.statusid,
                       lt.jobtypeid,
                       lt.statusdate
                  from query.j_application app
                  join query.r_applicationlicensetransfer alt on alt.AppTransferredToObjectId = app.JobId
                  join query.r_AppPrimaryLicenseType aplt on aplt.ApplicationObjectId = app.JobId
                  join query.o_PrimaryLicenseType plt on plt.ObjectId = aplt.LicenseTypeObjectId
                  join query.r_TransFromLTToPLT ltplt on ltplt.PrimaryLicenseTypeObjectId = plt.ObjectId
                  join query.j_Licensetype lt on lt.JobId = ltplt.LicenseTypeJobId
                  join api.jobstatuses js on js.StatusId = lt.StatusId and js.JobTypeId = lt.JobTypeid                   
                 where app.JobId = t_ApplicationJobId
                   and plt.IsTransferred = 'Y'
                   and js.StatusType in ('C', 'X')
                   and lt.LicenseTypeCode = api.pkg_ColumnQuery.Value(t_JobId, 'LicenseTypeCode')) loop  
        begin
          select max(st.Description) --should never get multiple rows.
          into t_PreviousStatus
          from extension.JobStatusChange jsc
          join api.statuses st on st.Tag = jsc.StatusName
          where jsc.JobId = j.lttransferredjobid
          and jsc.StatusDate = (select max(statusdate)
                                  from extension.jobstatuschange
                                  where jobid = jsc.JobId
                                  and statusdate < j.statusdate);
        exception when no_data_found then
          t_PreviousStatus := 'Active';
        end;
                                    
        t_ChangeStatusProcessId := api.pkg_ProcessUpdate.New(j.LTTransferredJobId, t_ChangeStatusProcessTypeId, 'Unissue License', null, null, null);
        api.pkg_processupdate.Complete(t_ChangeStatusProcessId, nvl(t_PreviousStatus, 'Active')); 
        for k in (select BatchType, 
                         ExpirationDate
                    from (select BatchType,
                                 max(ExpirationDate) ExpirationDate
                            from query.j_LicenseBatch lb
                           where BatchType in ('1ST RENEWAL NOTICES', '2ND RENEWAL NOTICES', 'FINAL REVOCATION PENDING LETTERS', 'AUTO REVOKE LICENSE TYPES')
                           group by BatchType
                           order by decode(BatchType, '1ST RENEWAL NOTICES', 1, '2ND RENEWAL NOTICES', 2, 'FINAL REVOCATION PENDING LETTERS', 3, 'AUTO REVOKE LICENSE TYPES', 4))
                   where ExpirationDate < j.ExpirationDate
                     and rownum = 1) loop
          if k.BatchType = '1ST RENEWAL NOTICES' then
            pkg_BatchType.SetBatchFlags(j.LTTransferredJobId, a_IncludeIn1stRenewal => 'Y');
          elsif k.BatchType = '2ND RENEWAL NOTICES' then
            pkg_BatchType.SetBatchFlags(j.LTTransferredJobId, a_IncludeIn2ndRenewal => 'Y');
          elsif k.BatchType = 'FINAL REVOCATION PENDING LETTERS' then
            pkg_BatchType.SetBatchFlags(j.LTTransferredJobId, a_IncludeInFinalRevPending => 'Y');
          elsif k.BatchType = 'AUTO REVOKE LICENSE TYPES' then
            pkg_BatchType.SetBatchFlags(j.LTTransferredJobId, a_IncludeInRevokeBatch => 'Y');
          end if;
        end loop;
      end loop;
    end if;    
  end UnissueLicenseType; 

----------------------------------------------------------------------------------------------------
-- SetExpMonthYear()
-- Using parameter of application objectid(????)
-- Set the ExpirationMonth and ExpirationYear using Primary License Type object data if exists.
----------------------------------------------------------------------------------------------------
  procedure SetExpMonthYear (
      a_ObjectId       udt_id,
      a_AsOfDate       date,
      a_JobId          udt_id ) is

  t_ExpMonNum    query.j_LicenseType.ExpiringMonthNumber%type;
  t_ExpMon       query.j_LicenseType.ExpiringMonth%type;
  t_ExpYear      query.j_LicenseType.ExpiringYear%type;
  t_NumMonslic   query.o_primarylicensetype.NumberOfMonthsLicensedNumber%type;
  t_ReadyToIssueDate                       date;
  t_LicenseTypeCode                        varchar(3);

  begin

    t_ReadyToIssueDate := sysdate; --previously the ready to issue date 
    
   -- Hardcode Expiring date on certain License Types
    t_LicenseTypeCode := api.pkg_columnquery.value(a_JobId, 'LicenseTypeCode');
   
   if t_LicenseTypeCode in ('02', '22', '26', '28') then
      select case 
               when to_char(sysdate,'MM') <= '06' 
                 then to_char(sysdate, 'YYYY')   
               else
                 to_char(add_months(sysdate, 12), 'YYYY') 
             end
             into t_ExpYear     
      from dual;       
        
      api.pkg_columnupdate.SetValue(a_JobId,'ExpiringMonth', 'JUNE');
      api.pkg_columnupdate.SetValue(a_JobId,'ExpiringYear', t_ExpYear);
     
   --Checking to see if we are issuing an 67,80 License Type, this will set the epiration date to the next June 30th in the timeline 
   elsif
      t_LicenseTypeCode in ('67', '80') then
      select case 
               when to_char(sysdate,'MM') <= '12' 
                 then to_char(sysdate, 'YYYY')   
               else
                 to_char(add_months(sysdate, 12), 'YYYY') 
             end
             into t_ExpYear     
      from dual;       
        
      api.pkg_columnupdate.SetValue(a_JobId,'ExpiringMonth', 'DECEMBER');
      api.pkg_columnupdate.SetValue(a_JobId,'ExpiringYear', t_ExpYear);
   else

   -- Set Expiring month (assume that all Seasonal Primary License Types ExpiringMonth detail will be set)
    t_ExpMonNum := api.pkg_columnquery.value(a_JobId,'ExpiringMonthNumber');
    
    if t_ExpMonNum is not null then
       -- If an Expiring Month Number exists then do nothing
       null;
    else
      -- Set the ExpiringMonth to the previous month from the current month)
      Case to_number(to_char(t_ReadyToIssueDate,'MM'))
        when 1 then t_ExpMon := 'DECEMBER';
        when 2 then t_ExpMon := 'JANUARY';
        when 3 then t_ExpMon := 'FEBRUARY';
        when 4 then t_ExpMon := 'MARCH';
        when 5 then t_ExpMon := 'APRIL';
        when 6 then t_ExpMon := 'MAY';
        when 7 then t_ExpMon := 'JUNE';
        when 8 then t_ExpMon := 'JULY';
        when 9 then t_ExpMon := 'AUGUST';
        when 10 then t_ExpMon := 'SEPTEMBER';
        when 11 then t_ExpMon := 'OCTOBER';
        when 12 then t_ExpMon := 'NOVEMBER';
        else null;
      end case;
      api.pkg_columnupdate.setValue(a_JobId,'ExpiringMonth',t_ExpMon);
    end if;
   end if;    
    

    -- Set Expiring year
    t_NumMonslic := api.pkg_columnquery.value(a_JobId,'NumberOfMonthsLicensedNumber');
    If t_NumMonslic > 0 then

      -- where month is the same or later than the ReadyToIssueDate month 
         If t_ExpMonNum >= to_number(to_char(t_ReadyToIssueDate,'MM'))
        then
        -- The expiration year is the current year
        t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY'));
      -- set year for seasonal license where month is earlier than the ReadyToIssueDate month
      else
        -- the expiration year is the current year + 1
        t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY')+1);
      end if;
    

    else
      -- set year for annual license
        -- Set year to current year when month is December 
      If t_ExpMon = 'DECEMBER' then  
        t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY'));
        -- Set year to next year when month is not December 
      else
        t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY')+1);
      end if;
    end if;
    api.pkg_columnupdate.setvalue(a_JobId,'ExpiringYear',t_ExpYear);
end SetExpMonthYear;

  /*---------------------------------------------------------------------------
   * ValidMasterLicenseTypesonPLT -- PUBLIC
   *  Find the Valid Master License Type Codes for a given Primary License Type
   *-------------------------------------------------------------------------*/
  function ValidMasterLicenseTypesonPLT (a_ObjectId         udt_Id
  ) return udt_LicenseTypeCodes is  
    t_LicenseTypeCodes       udt_LicenseTypeCodes;
  begin
    select ltc.LicenseTypeCode
      bulk collect into t_LicenseTypeCodes
      from api.Relationships re
      join query.o_LicenseTypeCategory ltc on ltc.ObjectId = re.FromObjectId
     where re.ToObjectId = a_ObjectId
       and ltc.SecondaryOnly = 'N' 
     union
    select ltc2.LicenseTypeCode 
      from api.Relationships re
      join query.o_LicenseTypeCategory ltc on ltc.objectid = re.FromObjectId
      join api.Relationships re2 on re2.fromobjectid = ltc.objectid
      join query.o_LicenseTypeCategory ltc2 on ltc2.objectid = re2.ToObjectId
     where re.ToObjectId = a_ObjectId
       and ltc.SecondaryOnly = 'Y'
       and ltc2.SecondaryOnly = 'N';
       
    return t_LicenseTypeCodes;    
  end ValidMasterLicenseTypesonPLT;


  /*---------------------------------------------------------------------------
   * ValidBranchLicenseTypesonPLT -- PUBLIC
   *  Find the Valid Branch License Type Codes for a given Primary License Type
   *-------------------------------------------------------------------------*/
  function ValidBranchLicenseTypesonPLT (a_ObjectId         udt_Id
  ) return udt_LicenseTypeCodes is  
    t_LicenseTypeCodes       udt_LicenseTypeCodes;
  begin
    select ltc.LicenseTypeCode
      bulk collect into t_LicenseTypeCodes
      from api.Relationships re
      join query.o_LicenseTypeCategory ltc on ltc.ObjectId = re.FromObjectId
     where re.ToObjectId = a_ObjectId
       and ltc.SecondaryOnly = 'N' 
     union
    select ltc2.LicenseTypeCode 
      from api.Relationships re
      join query.o_LicenseTypeCategory ltc on ltc.objectid = re.FromObjectId
      join api.Relationships re2 on re2.fromobjectid = ltc.objectid
      join query.o_LicenseTypeCategory ltc2 on ltc2.objectid = re2.ToObjectId
     where re.ToObjectId = a_ObjectId
       and ltc2.BranchApplies = 'Y'
       and ltc.SecondaryOnly = 'N'
       and ltc2.SecondaryOnly = 'Y';
       
    return t_LicenseTypeCodes;    
  end ValidBranchLicenseTypesonPLT;

  /*---------------------------------------------------------------------------
   * VerifyLicenseTypeonPLT -- PUBLIC
   *  Find the Valid License Type Codes for a given Primary License Type
   *-------------------------------------------------------------------------*/
  procedure VerifyLicenseTypeonPLT (a_RelationshipId   udt_Id,
                                    a_AsOfDate         date
  ) is  
    t_PLTObjectId              udt_Id;
    t_LTJobId                  udt_Id;
    t_LicenseTypeCodes         udt_LicenseTypeCodes;
  begin 
    select r.fromobjectid, --PrimaryLicenseTypeObjectId,
           r.toobjectid --LicenseTypeJobId
      into t_PLTObjectId,
           t_LTJobId
      from api.relationships r --query.r_MasterLTBranchPrimaryLT
     where RelationshipId = a_RelationshipId
       and endpointid in (api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'MasterPrimaryLicenseType'),
                          api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'MasterLicenseType'));
--branch to master
    t_LicenseTypeCodes := ValidMasterLicenseTypesonPLT(t_PLTObjectId);
    for i in 1..t_LicenseTypeCodes.count loop
      if t_LicenseTypeCodes(i) = api.pkg_ColumnQuery.Value(t_LTJobId, 'LicenseTypeCode') then
       return;
      end if;
    end loop;

--master to branch
    if api.pkg_columnquery.value(t_PLTObjectId, 'MasterLicenseType') is null
     then
      t_LicenseTypeCodes := ValidBranchLicenseTypesonPLT(t_PLTObjectId);
      for m in 1..t_LicenseTypeCodes.count loop
        if t_LicenseTypeCodes(m) = api.pkg_ColumnQuery.Value(t_LTJobId, 'LicenseTypeCode') then
          return;
        end if;
      end loop;
    end if;
    
    api.pkg_Errors.SetArgValue('Primary License Type Code', api.pkg_ColumnQuery.Value(t_PLTObjectId, 'LicenseTypeCode'));
    api.pkg_Errors.SetArgValue('Master License Type Code', api.pkg_ColumnQuery.Value(t_LTJobId, 'LicenseTypeCode'));
    api.pkg_Errors.SetArgValue('Primary License Type Number', api.pkg_ColumnQuery.Value(t_LTJobId, 'LicenseNumber'));
    api.pkg_Errors.SetArgValue('Master License Type Number', api.pkg_ColumnQuery.Value(t_LTJobId, 'LicenseExternalFileNum'));
    api.pkg_Errors.RaiseError(-20000, 'License Type ' || api.pkg_ColumnQuery.Value(t_LTJobId, 'LicenseTypeCode') || '-' || 
                                       api.pkg_ColumnQuery.Value(t_LTJobId, 'LicenseExternalFileNum') || ' is not valid as a 
                                       Master or Branch License Type for this License Type Code, ' || 
                                       api.pkg_columnquery.value(t_PLTObjectId, 'LicenseTypeCode') || '.');
    
  end VerifyLicenseTypeonPLT;
  
  /*---------------------------------------------------------------------------
   * ReinstateLicType -- PUBLIC
   *-------------------------------------------------------------------------*/
--  procedure ReinstateLicType (a_processid   udt_id,
--                              a_AsOfDate    date
--                              ) is
--    t_Jobid udt_id := api.pkg_columnquery.Value(a_processid, 'JobId');
--  begin
--      api.pkg_columnupdate.SetValue(t_jobid, 'TypeOfIssuance', 'REINSTATEMENT');
--      
--  end ReinstateLicType;

--------------------------------------------------------------------------------------------------- 
-- ReinstateLicType -- PUBLIC
-- Reinstate a License Type Job.
-- primary and secondary license type has TypeOfIssuance set; Primary has four other SetValue actions.
-- If there are REN, REN50, REN100 fees owing on either the License Job or License Type Job 
-- raise an error.
-- The OverrideBalanceOwingCheck bool will allow an override for the error.
---------------------------------------------------------------------------------------------------   
  procedure ReinstateLicType (a_processid   udt_id,
                              a_AsOfDate    date,
                              a_OverrideBalanceOwingCheck char
                              ) is
    t_LTJobId udt_id := api.pkg_columnquery.Value(a_processid, 'JobId');
    t_LicJobId udt_id := api.pkg_columnquery.Value(t_LTJobid, 'LicenseJobId');        
    t_PriRel char; 
    t_OweRenFees number;
    t_LTStatusName extension.jobstatuschange.statusname%type;
    t_SecLTStatusCount number;    
  begin  

    -- Config allows the Reinstate process to be inserted regardless if the Primary LT needs it.
    -- So check that either the License Type Job or any one of the Secondary LT status needs Reinstating.
    -- Present error if not, because the Reinstate process has no purpose.

    t_LTStatusName := api.pkg_columnquery.Value(t_LTJobid, 'StatusName');
      
    select count(*) into t_SecLTStatusCount
    from query.r_LicenseTypeLTCatSecondary slt
    where slt.LicenseTypeJobId = t_LTJobid
    and slt.Status in('AUTO REVOKED', 'REV PENDING', 'DEPARTMENT REVOKED', 'SLMS REVOKED');      

    if (t_LTStatusName not in ('AUTREV', 'DEPREV', 'REVPEN', 'SLMSRV')
        or (t_LTStatusName in ('ACTIVE', 'R64B', 'SLMSHD', 'SUREND', 'SUSPEN')
        and t_SecLTStatusCount < 1 ))
    then api.pkg_errors.RaiseError(-20000,'Reinstate Process is not necessary. No License Type can be Reinstated.');      

    else

-- is this a primary license type
      begin
        select 'Y' into t_PriRel 
        from query.r_licenselicensetype llt 
        where llt.LicenseTypeJobId = t_LTJobId;       
      exception when no_data_found
        then t_PriRel := 'N';
      end;
    
      if a_OverrideBalanceOwingCheck = 'Y'  
      then 
          api.pkg_columnupdate.SetValue(t_LTJobId, 'TypeOfIssuance', 'RENEWAL'); 
          if t_PriRel = 'Y'   
            then 
              api.pkg_columnupdate.SetValue(t_LTJobId, 'Reinstate', 'Y');              
            
              api.pkg_columnupdate.SetValue(t_LTJobId, 'ReadyToIssueDate', trunc(sysdate));          
  --            set flags to 'Y' ; all others set to 'N' by default
              sitespecific.pkg_batchtype.SetBatchFlags(
                  t_LTJobid, 
                  a_IncludeInProduceLicenseBatch => 'Y', 
                  a_IncludeInDailyBatch => 'Y'); 
                  
              for c in (select ltcs.relationshipid, ltcs.LicenseTypeJobId, ltcs.LicenseTypeCategoryObjectId
                          from query.r_Licensetypeltcatsecondary ltcs
                        where ltcs.LicenseTypeJobId = t_LTJobId
                          and ltcs.Status in ('AUTO REVOKED', 'REV PENDING', 'DEPARTMENT REVOKED', 'SLMS REVOKED'))loop -- handle secondaries     
                
                api.pkg_columnupdate.SetValue(c.relationshipid, 'ReadyToIssueDate', trunc(sysdate));      
                
                -- Set Ready to Issue Date on Duplicates
                for c_dup in (select d.duplicateid ObjectId
                        from sitespecific.duplicate_t d
                       where d.LicenseTypeJobid = c.LicenseTypeJobid
                         and d.LicenseTypeCategoryObjectID = c.LicenseTypeCategoryObjectId
                         and d.relationshipid = c.relationshipid) loop
                  api.pkg_columnupdate.SetValue(c_dup.objectid, 'ReadyToIssueDate', trunc(sysdate));
                                  
                end loop;
                    
  --            set flags to 'Y' ; all others set to 'N' by default
                sitespecific.pkg_batchtype.SetBatchFlags(
                  c.relationshipid, 
                  a_IncludeInProduceLicenseBatch => 'Y', 
                  a_IncludeInDailyBatch => 'Y');           
                          
              end loop;                        
          end if;          
      else
        begin
          select sum((f.Amount + nvl((select sum(Amount) from api.FeeTransactions ft where ft.FeeId = f.FeeId),0))) 
            into t_OweRenFees 
            from api.fees f
            where f.JobId in (t_LicJobId, t_LTJobId) 
            and f.GLAccountId in(select g.GLAccountId
                                   from api.glaccounts g
                                  where g.GLAccount in ('REN', 'REN50', 'REN100'));
                
         exception when no_data_found then
           null;
         end;
         
        if t_OweRenFees > 0              
         
            then api.pkg_errors.RaiseError(-20000,'Outstanding Fee balance is preventing Reinstatement.');             
        else 
            api.pkg_columnupdate.SetValue(t_LTJobId, 'TypeOfIssuance', 'RENEWAL'); 
            if t_PriRel = 'Y'             
              then 
                api.pkg_columnupdate.SetValue(t_LTJobId, 'Reinstate', 'Y');                
                api.pkg_columnupdate.SetValue(t_LTJobId, 'ReadyToIssueDate', trunc(sysdate));          
  --            set flags to 'Y' ; all others set to 'N' by default
                sitespecific.pkg_batchtype.SetBatchFlags(
                    t_LTJobid, 
                    a_IncludeInProduceLicenseBatch => 'Y', 
                    a_IncludeInDailyBatch => 'Y');
                    
             for c in (select ltcs.relationshipid, ltcs.LicenseTypeJobId, ltcs.LicenseTypeCategoryObjectId
                          from query.r_Licensetypeltcatsecondary ltcs
                        where ltcs.LicenseTypeJobId = t_LTJobId 
                          and ltcs.Status in ('AUTO REVOKED', 'REV PENDING', 'DEPARTMENT REVOKED', 'SLMS REVOKED'))loop -- handle secondaries     
                
                api.pkg_columnupdate.SetValue(c.relationshipid, 'ReadyToIssueDate', trunc(sysdate));          
                
                --Set Ready to Issue Date on Duplicates
                for c_dup in (select d.duplicateid ObjectId
                        from sitespecific.duplicate_t d
                       where d.LicenseTypeJobid = c.LicenseTypeJobid
                         and d.LicenseTypeCategoryObjectID = c.LicenseTypeCategoryObjectId
                         and d.relationshipid = c.relationshipid) loop
                  api.pkg_columnupdate.SetValue(c_dup.objectid, 'ReadyToIssueDate', trunc(sysdate));
                end loop;
                
  --            set flags to 'Y' ; all others set to 'N' by default
                sitespecific.pkg_batchtype.SetBatchFlags(
                  c.relationshipid, 
                  a_IncludeInProduceLicenseBatch => 'Y', 
                  a_IncludeInDailyBatch => 'Y');           
                          
              end loop; 
                                    
            end if; -- Primary LT          
        end if;  -- Outstanding Renewal Fees     
      end if; -- Balance Override    
    end if; -- Status check
    
  end ReinstateLicType;










  
   /*--------------------------------------------------------------------------
   * ChangeSecLicTypeStatus() -- PUBLIC
   * Sets all the secondary license types on a license type job that aren't
   * cancelled to a specified status.
   *-------------------------------------------------------------------------*/
  procedure ChangeSecLicTypeStatus(a_processid   udt_id,
                                   a_AsOfDate    date,
                                   a_JobId       udt_id,
                                   a_Status      varchar2) is
  begin  

      for c in (select slt.relationshipid
                  from query.r_licensetypeltcatsecondary slt 
                 where slt.LicenseTypeJobId = a_JobId --License Type Jobid
                   and slt.status not in ('CANCELED', 'AUTO REVOKED', 'DENIED', 'DEPARTMENT REVOKED', 'NON-RENEWED', 'SLMS REVOKED', 'VOIDED', 'WITHDRAWN')) loop
        --Set Status
        api.pkg_columnupdate.SetValue(c.relationshipid, 'Status', a_Status);
      end loop;
  end ChangeSecLicTypeStatus;
  
  /*-------------------------------------------------------------------------
  * SetBranchDetail() - Public
  * This procedure is used to set details on the Branch LTs based off their
  * Master LT
  *------------------------------------------------------------------------*/

  procedure SetBranchDetail(a_Objectid                    udt_id,
                            a_AsofDate                    date,
                            a_SourceColumnName            varchar2,
                            a_TargetColumnName            varchar2
                           )is
                           
  t_Value  varchar2(50);

  begin

  t_Value := api.pkg_columnquery.value(a_ObjectId, a_SourceColumnName);

      for c in(select r.ToObjectId BranchId
                 from api.relationships r
                where r.endpointid = api.pkg_configquery.endpointidforname('j_LicenseType', 'BranchLicenseType')
                  and r.fromobjectid = a_Objectid)loop

         api.pkg_columnupdate.setvalue(c.branchid, a_TargetColumnName, t_Value);


      end loop;

  end SetBranchDetail;
  
  ----------------------------------------------------------------------------------------------------
  --   * SetExpMonthYear()
  --Run on outcome of the produce license batch to set the expiring month and year when the expiration date is null
  ----------------------------------------------------------------------------------------------------
  procedure SetExpMonthYearBatch (
    a_ObjectId       udt_id, --used for the ready to issue date, grab from licensetype?
    a_JobId          udt_id,
    a_AsOfDate       date)
  is --license type job id
    t_ExpMonNum    query.j_LicenseType.ExpiringMonthNumber%type;
    t_ExpMon       query.j_LicenseType.ExpiringMonth%type;
    t_ExpYear      query.j_LicenseType.ExpiringYear%type;
    t_NumMonslic   query.o_primarylicensetype.NumberOfMonthsLicensedNumber%type;
    t_ReadyToIssueDate                       date;
    t_AddRenewalFee                        varchar2(1);
    t_DesignatedExpirationDate             varchar2(1);
    t_UpgradedLicense                      varchar2(1);
    t_TransferedFromLicenseId              number;
  begin
    t_ReadyToIssueDate := api.pkg_columnquery.DateValue(a_JobId, 'ReadyToIssueDate');
    t_DesignatedExpirationDate := api.pkg_columnquery.Value(a_JobId,'DesignatedExpirationDate');

    -- Set the ExpiringMonth to the previous month from the current month)
    Case to_number(to_char(t_ReadyToIssueDate,'MM'))
      when 1 then t_ExpMon := 'DECEMBER';
      when 2 then t_ExpMon := 'JANUARY';
      when 3 then t_ExpMon := 'FEBRUARY';
      when 4 then t_ExpMon := 'MARCH';
      when 5 then t_ExpMon := 'APRIL';
      when 6 then t_ExpMon := 'MAY';
      when 7 then t_ExpMon := 'JUNE';
      when 8 then t_ExpMon := 'JULY';
      when 9 then t_ExpMon := 'AUGUST';
      when 10 then t_ExpMon := 'SEPTEMBER';
      when 11 then t_ExpMon := 'OCTOBER';
      when 12 then t_ExpMon := 'NOVEMBER';
      else null;
    end case;

    api.pkg_columnupdate.setValue(a_JobId,'ExpiringMonth',t_ExpMon);
    
    begin
    
    select 
      case 
        when lt.transfromltcode = lt.transtoltcode
          then 'N' 
        when lt.transfromltcode != lt.transtoltcode
          then 'Y'  
      end UpgradeLicense,
      lt.transfromltjobid 
    into t_UpgradedLicense, t_TransferedFromLicenseId    
    from
      sitespecific.licensetransfers_t lt
     where lt.transtoltjobid = a_JobId;
    
    exception when no_data_found then
      t_UpgradedLicense := 'N';
    end;
    
  if t_UpgradedLicense = 'N' then
    if t_DesignatedExpirationDate = 'Y' then
      t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY'));
      t_NumMonslic := api.pkg_columnquery.value(a_JobId,'NumberOfMonthsLicensedNumber');
    elsif t_NumMonslic > 0 then
      If t_ExpMonNum >= to_number(to_char(t_ReadyToIssueDate,'MM')) then
        t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY'));
      else
        t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY')+1);
      end if;
    else
      if t_ExpMon = 'DECEMBER' then
        t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY'));
      else
        t_ExpYear := to_number(to_char(t_ReadyToIssueDate,'YYYY')+1);
      end if;
    end if;
  else 
  
  t_ExpMon := api.pkg_columnquery.Value(t_TransferedFromLicenseId,'ExpiringMonth');  
  
  api.pkg_columnupdate.setValue(a_JobId,'ExpiringMonth',t_ExpMon);
    
  t_ExpYear := api.pkg_columnquery.Value(t_TransferedFromLicenseId,'ExpiringYear');  
    
  end if; 
  
    api.pkg_columnupdate.setvalue(a_JobId,'ExpiringYear',t_ExpYear);
    
    --api.pkg_errors.RaiseError(-20001, 'Got here: ' || t_UpgradedLicense);
    
  end SetExpMonthYearBatch;  

  /*-------------------------------------------------------------------------
  * CorrectSecondaryRel() - Public
  * This procedure is used on the outcome of the p_CorrectSecondary process
  * to move the relationship of a chosen Secondary from one Primary LT to
  * another.
  *------------------------------------------------------------------------*/

  procedure CorrectSecondaryRel(a_Objectid             udt_id,
                                a_AsofDate             date,
                                a_SecondaryLTCObjectId udt_id,
                                a_ToPrimaryLTObjectId  udt_id) is
  
    t_OldSecondaryRel   query.r_LicenseTypeLTCatSecondary%rowtype;
    t_NewSecondaryRelId udt_id;
  
  begin
  
    --store the information for the secondary rel
    select sltc.*
      into t_OldSecondaryRel
      from query.r_CorrectSecondaryFromLT flt
      join query.r_LicenseTypeLTCatSecondary sltc on sltc.LicenseTypeJobId =
                                                     flt.LicenseTypeJobId
     where flt.CorrectSecondaryProcessId = a_Objectid
       and sltc.LicenseTypeCategoryObjectId = a_SecondaryLTCObjectId;
  
    api.pkg_relationshipupdate.Remove(t_OldSecondaryRel.RelationshipId);
    
    --recreate the old rel connected to the ToPrimaryLicenseType
    t_NewSecondaryRelId := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName('j_LicenseType', 'LicTypeCatSecondary'), a_ToPrimaryLTObjectId, a_SecondaryLTCObjectId);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'IncludeIn1stRenewal', t_OldSecondaryRel.IncludeIn1stRenewal);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'IncludeIn2ndRenewal', t_OldSecondaryRel.IncludeIn2ndRenewal);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'IncludeInDailyBatch', t_OldSecondaryRel.IncludeInDailyBatch);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'IncludeInFinalRevPending', t_OldSecondaryRel.IncludeInFinalRevPending);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'IncludeInProduceLicenseBatch', t_OldSecondaryRel.IncludeInProduceLicenseBatch);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'IncludeInRevokeBatch', t_OldSecondaryRel.IncludeInRevokeBatch);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'IssueDate', t_OldSecondaryRel.IssueDate);
    --api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'LicenseTypeCount', t_OldSecondaryRel.LicenseTypeCount);Commented by Pawan on 1/20/2016 to fix issue WO-8763
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'Print', t_OldSecondaryRel.Print);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'ReadyToIssueDate', t_OldSecondaryRel.ReadyToIssueDate);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'Status', t_OldSecondaryRel.Status);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'StatusDate', t_OldSecondaryRel.StatusDate);
    api.pkg_columnupdate.SetValue(t_NewSecondaryRelId, 'TypeOfIssuance', t_OldSecondaryRel.TypeOfIssuance);
    
    -- Move Duplicates
    for c_dup in (select d.duplicateid ObjectId
                    from sitespecific.duplicate_t d
                   where d.LicenseTypeJobid = t_OldSecondaryRel.LicenseTypeJobid
                     and d.LicenseTypeCategoryObjectID = t_OldSecondaryRel.LicenseTypeCategoryObjectId
                     and d.relationshipid = t_OldSecondaryRel.relationshipid) loop
                     
      api.pkg_columnupdate.SetValue(c_dup.objectid, 'RelationshipID', t_NewSecondaryRelId);
      api.pkg_columnupdate.SetValue(c_dup.objectid, 'LicenseTypeCategoryObjectID', a_SecondaryLTCObjectId);
      api.pkg_columnupdate.SetValue(c_dup.objectid, 'LicenseTypeJobId', a_ToPrimaryLTObjectId);
                        
    end loop;
    
    --delete any new records in the SLT status change history table
    delete from sitespecific.sltstatuschange_t sc
     where sc.relationshipid = t_NewSecondaryRelId;
     
    --switch all of the SLT status change records to the new rel
    update sitespecific.sltstatuschange_t sc
       set sc.relationshipid = t_NewSecondaryRelId,
           sc.fromobjectid = a_ToPrimaryLTObjectId,
           sc.toobjectid = a_SecondaryLTCObjectId
     where sc.relationshipid = t_OldSecondaryRel.RelationshipId;
  
  end CorrectSecondaryRel;

  /*-------------------------------------------------------------------
  -- SetPrimaryLTStatus()
  -- This runs on an outcome of a process and sets the PLT/SLT statuses
  -- to the status the outcome is going to.
  */-------------------------------------------------------------------
  procedure SetPrimaryLTStatus(a_ObjectId     udt_Id,
                               a_AsOfDate     date,
                               a_JobId        udt_Id) as
    t_Status   varchar2(30);
  begin
    -- Get the status from the job
    begin
    select unique upper(s.Description)
      into t_Status
      from api.JobTypeProcessTypes pt
      join api.ProcessOutcomes po on po.JobTypeProcessTypeId = pt.JobTypeProcessTypeId
      join api.StatusChanges sc on sc.ProcessOutcomeId = po.ProcessOutcomeId
      join api.Statuses s on s.StatusId = sc.ToStatusId
     where pt.JobTypeId = api.pkg_ColumnQuery.NumericValue(a_JobId,'ObjectDefId')
       and pt.ProcessTypeId = api.pkg_ColumnQuery.NumericValue(a_ObjectId,'ObjectDefId')
       and po.Outcome = api.pkg_ColumnQuery.Value(a_ObjectId,'Outcome')
       and (sc.FromStatusId = api.pkg_columnquery.Value(a_JobId, 'StatusId')
        or sc.FromStatusId is null);
    exception when no_data_found then
      select upper(s.Description)
      into t_Status
      from api.statuses s
      where s.statusid = api.pkg_columnquery.Value(a_JobId,'StatusId');
    end;
    
    -- Update the status and status date on the PLT and any Secondaries
    for c in (select r.LicenseTypeObjectId
                from query.r_AppPrimaryLicenseType r
               where r.ApplicationObjectId = a_JobId) loop
      api.pkg_ColumnUpdate.SetValue(c.LicenseTypeObjectId,'Status',t_Status);
      api.pkg_ColumnUpdate.SetValue(c.LicenseTypeObjectId,'StatusDate',sysdate);
      for x in (select s.RelationshipId
                  from query.r_PriLTLTCatSecondary s
                 where s.PrimaryLicenseTypeObjectId = c.LicenseTypeObjectId) loop
        api.pkg_ColumnUpdate.SetValue(x.RelationshipId,'SStatus',t_Status);
        api.pkg_ColumnUpdate.SetValue(x.RelationshipId,'StatusDate',sysdate);
      end loop;
    end loop;
  end SetPrimaryLTStatus;

  /*-------------------------------------------------------------------------
  *   TJL - WO 14255 02/28/2018
  *
  * CorrectPriorityRel() - Public
  * This procedure is used to add back the priority license type priority 
  * when the license type is changed on priority application 
  *------------------------------------------------------------------------*/
  procedure CorrectPriorityRel(a_Objectid             udt_id,
                               a_AsofDate             date) AS

    t_application    udt_id;
    t_count          NUMBER;
    t_relid          udt_id;
    t_licTypeCat     udt_id;
                               
  begin                               
    begin
        -- get application object id
        select r.toobjectid
          into t_application
          from api.relationships r
         where r.fromobjectid = a_Objectid
           and r.endpointid	= api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'Application');
    exception when NO_DATA_FOUND THEN
        t_application := NULL;
    end;
    
    if (t_application is not null) then
        -- check if priority application
        if (api.pkg_columnquery.value(t_application, 'IsPriorityApplication') = 'Y') then
            -- check if a priority releationship exist
            select count(1)
              into t_count
              from api.relationships r
             where --SG Fix for creating too many priority license types and license type categories.
                    --r.toobjectid = a_Objectid
                   r.FromObjectId = t_application
               and r.endpointid	= api.pkg_configquery.EndPointIdForName('j_application', 'PriorityPriLicenseType');
            
            if (t_count = 0) then
                -- get license type category
                select r.toobjectid
                  into t_licTypeCat
                  from api.relationships r
                 where r.fromobjectid = a_Objectid
                   and r.endpointid	= api.pkg_configquery.EndPointIdForName('o_PrimaryLicenseType', 'LicTypeCatPrimary');
            
                -- create relationship as a priority license type
                t_relid := api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname ('j_application', 
                                                                                                 'PriorityPriLicenseType'), 
                                                          t_application, a_Objectid);
                                                          
                t_relid := api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname ('o_PrimaryLicenseType', 
                                                                                                 'LicTypeCatPriority'), 
                                                          a_Objectid,
                                                          case api.pkg_columnquery.value(t_licTypeCat, 'Retailtype') 
                                                                when 'On-Sale' then 7926 -- 47
                                                                               else 7924 -- 21
                                                          end);
            end if;
        end if;
    end if;
  end CorrectPriorityRel;

  /*-------------------------------------------------------------------------
  *   Priority Item #5B - GenerateSLTFees
  *   Author: Shane Gilbert
  *   This procedure will validate and generate fees when secondary license types 
  *   added to a pending application
  *   Called from the Primary License Type
  *------------------------------------------------------------------------*/
  procedure GenerateSLTFees (a_Objectid             udt_id,
                             a_AsofDate             date) AS
    t_application      udt_id;
    t_PrimaryLTEPId    udt_Id := api.Pkg_Configquery.EndPointIdForName( 'o_PrimaryLicenseType' , 'LicTypeCatSecondary') ;
    t_PriorityLTEPId   udt_id := api.Pkg_Configquery.EndPointIdForName( 'o_PrimaryLicenseType' , 'LicTypeCatPriority') ; 
    t_FeeScheduleEPId  udt_id := api.Pkg_Configquery.EndPointIdForName( 'o_fee', 'LicenseFeeSchedule' ); 
    t_FeeDefId         udt_id := api.pkg_configquery.objectdefidforname('o_Fee');       
    t_CreateFees       boolean := false;
    t_error            varchar2(4000) := ' ';
  begin   
     --find the application for the primary license type
     for x in ( select distinct plt.ApplicationObjectId
                  from query.o_PrimaryLicenseType plt
                 where plt.ObjectId = a_ObjectId ) loop
                 
         --exit if this primary license type is not for an application         
         --using API view to avoid performance issues with query.r_PriLTLTCatSecondary    
         if x.Applicationobjectid is null then
            exit;
         end if;

         --check the create fees flag for each secondary license type
         --set the create fees to N regardless of application status
         for y in ( select r.RelationshipId
                      from api.Relationships r
                     where r.EndPointId in ( t_PrimaryLTEPId ,t_PriorityLTEPId )  
                       and r.FromObjectId = a_ObjectId ) loop
            if api.pkg_ColumnQuery.Value( y.RelationshipId, 'CreateFees' ) = 'Y' then
               t_createfees := true;
               api.pkg_ColumnUpdate.SetValue( y.Relationshipid, 'CreateFees', 'N' );
            end if;
         end loop;
                    
         --if the application is not in a pending status exit
         if api.Pkg_Columnquery.Value( x.applicationobjectid , 'StatusDescription' ) <> 'Pending' then
           --do not add fees to applications if not in a pending status
           exit;
         end if;  
         
         --if no secondary license type has the create fees flag then exit
         if not t_createfees then
           exit;
         end if;

         --application validation
         if api.pkg_ColumnQuery.Value( x.applicationobjectid, 'EstimatedIssueDate' ) is null then
           t_error := 'Please Return to Job and enter the Estimated Issue Date.';
         end if;
            
         if api.pkg_ColumnQuery.NumericValue( x.applicationobjectid, 'DupSecLTError' ) > 0 then
           t_error := 'You cannot have the same Secondary License Type on multiple Primary License Types.';
         end if;
         
         if api.pkg_ColumnQuery.Value( x.applicationobjectid, 'RaiseErrSeasonal' ) = 'Y' then
           t_error := 'Please Return to Job and enter the Seasonal information for the applicable Primary License Types.';
         end if;
            
         if api.pkg_ColumnQuery.Value( x.applicationobjectid, 'RaiseErrGallonage' ) = 'Y' then
           t_error := 'Please Return to Job and enter the Gallonage Range for the applicable Primary License Types.';
         end if;    

         --call exception if one was found
         if length( t_error ) > 1 then
            api.pkg_errors.RaiseError(-20000, t_error );
         end if; 
          
         --call the generate application fees procedure
         if length( t_error ) = 1 then
            sitespecific.pkg_Fees.applicationfeecalc ( x.applicationobjectid, sysdate, x.applicationobjectid);
         end if;
                   
      end loop;
  end GenerateSLTFees;  

  /*-------------------------------------------------------------------------
  *   Priority Item #5B - RemoveSLTFees
  *   Author: Shane Gilbert  
  *   This procedure will remove secondary license type fees when removed and 
  *   no payments have been made 
  *
  *   Called from the deleting procedure
  *------------------------------------------------------------------------*/
  procedure RemoveSLTFees (a_Objectid             udt_id,
                           a_AsofDate             date) AS
    t_Application      udt_id;
    t_PrimaryLTEPId    udt_Id := api.Pkg_Configquery.EndPointIdForName( 'o_PrimaryLicenseType' , 'LicTypeCatSecondary') ;
    t_PriorityLTEPId   udt_id := api.Pkg_Configquery.EndPointIdForName( 'o_PrimaryLicenseType' , 'LicTypeCatPriority') ; 
    t_FeeScheduleEPId  udt_id := api.Pkg_Configquery.EndPointIdForName( 'o_fee', 'LicenseFeeSchedule' );
    t_FeeDefId         udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
    t_LicenseTypeCode  varchar(3);  
    t_Amount NUMBER;
    t_Return number;
  begin   

    for x in (select r.FromObjectId, r.ToObjectId  
                from api.Relationships r
               where r.EndPointId in ( t_PrimaryLTEPId ,t_PriorityLTEPId )  
                 and r.RelationshipId = a_ObjectId ) loop
                    
         t_Application := api.Pkg_Columnquery.NumericValue( x.Fromobjectid, 'Applicationobjectid') ;
         
         --exit if this primary license type is not for an application         
         if t_Application is null then
            exit;
         end if;
                    
         --if the application is not in a pending status exit
         if api.Pkg_Columnquery.Value( t_Application , 'StatusDescription' ) <> 'Pending' then
           --do not remove fees from applications when not in a pending status
           exit;
         end if;  
         
         t_LicenseTypeCode := api.pkg_ColumnQuery.Value(x.Toobjectid, 'LicenseTypeCode' );
        --if any payments have been made for the secondary license type fee that have not been voided then throw an exception
         for y in ( select r.RelationshipId 
                      from api.fees f
                      join api.registeredexternalobjects reo
                                                     on reo.linkvalue = TO_CHAR(f.feeid)
                                                    and reo.objectdefid = t_FeeDefId
                      join api.relationships r on r.FromObjectId = reo.ObjectId      
                      join sitespecific.feeschedule_t fs on fs.objectid = r.ToObjectId              
                     where f.JobId = t_Application
                       and r.EndPointId = t_FeeScheduleEPId
                       and f.Amount > 0
                       and f.Description like t_LicenseTypeCode || ' - DOR%'
                       and exists ( select 1
                                      from api.feetransactions ft
                                      join api.paymenttransactions pt on pt.TransactionId = ft.TransactionId
                                     where ft.FeeId = f.FeeId
                                       and pt.VoidedByTransactionId is null ) ) loop
              api.pkg_errors.RaiseError(-20000, 'Receipted payments must be voided to complete this process.' );
          end loop;    
          
          --Modify the fee voiding it, if payment transactions exist and have been voided. 
          for y in ( select r.RelationshipId, f.FeeId 
                      from api.fees f
                      join api.registeredexternalobjects reo
                                                     on reo.linkvalue = TO_CHAR(f.feeid)
                                                    and reo.objectdefid = t_FeeDefId
                      join api.relationships r on r.FromObjectId = reo.ObjectId      
                      join sitespecific.feeschedule_t fs on fs.objectid = r.ToObjectId              
                     where f.JobId = t_Application
                       and r.EndPointId = t_FeeScheduleEPId
                       and f.Amount > 0
                       and f.Description like t_LicenseTypeCode || ' - DOR%'
                       and exists ( select 1
                                      from api.feetransactions ft
                                      join api.paymenttransactions pt on pt.TransactionId = ft.TransactionId
                                     where ft.FeeId = f.FeeId
                                       and pt.VoidedByTransactionId is not null ) ) loop
                                       
              Select -(nvl(sum(f.Amount+f.TaxAmount), 0) +
                                nvl((select sum(ft.Amount+ft.TaxAmount)
                                       from api.FeeTransactions ft 
                                      where ft.FeeId = f.FeeId), 0) ) as Balance
                into t_Amount
                from api.fees f
               Where f.FeeId = y.FeeId
               Group by f.FeeId;
               
               if t_amount <> 0 then               
                 t_Return := api.pkg_feeupdate.adjust(y.Feeid,
                                                      t_amount,
                                                     'Removed SLT: Modify Fee – Void',
                                                      a_AsofDate );                       
               end if;                                                      

          end loop;            
                     
          --if no payment transactions exist for the secondary license type then remove the fee
          for y in ( select r.RelationshipId, f.FeeId 
                      from api.fees f
                      JOIN api.registeredexternalobjects reo
                                                     ON reo.linkvalue = TO_CHAR(f.feeid)
                                                    AND reo.objectdefid = t_FeeDefId
                      join api.relationships r on r.FromObjectId = reo.ObjectId      
                      join sitespecific.feeschedule_t fs on fs.objectid = r.ToObjectId              
                     where f.JobId = t_Application
                       and r.EndPointId = t_FeeScheduleEPId
                       and f.Amount > 0
                       and f.Description like t_LicenseTypeCode || ' - DOR%'
                       and not exists ( select 1
                                         from api.feetransactions ft
                                         join api.paymenttransactions pt on pt.TransactionId = ft.TransactionId
                                        where ft.FeeId = f.FeeId  )) loop
               api.pkg_Feeupdate.Remove(y.FeeId);
          end loop;   
                                                      
      end loop;
  end RemoveSLTFees;  
  
end pkg_LicenseType;
/
