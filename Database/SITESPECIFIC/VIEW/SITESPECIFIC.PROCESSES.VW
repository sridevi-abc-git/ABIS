CREATE OR REPLACE FORCE VIEW SITESPECIFIC.PROCESSES
(LOGICALTRANSACTIONID, PROCESSID, EXTERNALFILENUM, JOBID, SEQNUM, 
 PROCESSTYPEID, JOBTYPEPROCESSTYPEID, PROCESSSTATUS, DESCRIPTION, SCHEDULEDSTARTDATE, 
 SCHEDULEDCOMPLETEDATE, DATESTARTED, DATECOMPLETED, COMPLETEDBYUSERID, COMPLETEDBY, 
 OUTCOME, CREATEDBYUSERID, CREATEDBY, CREATEDDATE, ASSIGNEDSTAFF, 
 OBJECTMAINTENANCEBLOCKID, COMPLETEDBYLOGICALTRANSID, CANDELETE, CANMODIFY, CANCOMPLETE)
BEQUEATH DEFINER
AS 
select logicaltransactionid,
       processid,
       externalfilenum,
       jobid,
       seqnum,
       processtypeid,
       jobtypeprocesstypeid,
       processstatus,
       description,
       scheduledstartdate,
       scheduledcompletedate,
       datestarted,
       datecompleted,
       completedbyuserid,
       completedby,
       outcome,
       createdbyuserid,
       createdby,
       createddate,
       assignedstaff,
       objectmaintenanceblockid,
       completedbylogicaltransid,
       case when p.Outcome is null
         then case when (select count(*)
                           from sitespecific.ProcessSecurity_APIBREAK ps
                          where ps.SecurityPrivilegeId = 4 -- Delete
                            and ps.ProcessId = p.ProcessId
                            and rownum <= 1) > 0
                then 'Y'
                else 'N'
              end
          else 'N'
       end  CanDelete,
       case when p.Outcome is null
         then case when (select count(*)
                           from sitespecific.ProcessSecurity_APIBREAK ps
                          where ps.SecurityPrivilegeId = 3 -- Modify
                            and ps.ProcessId = p.ProcessId
                            and rownum <= 1) > 0
                then 'Y'
                else 'N'
              end
           else 'N'
       end  CanModify,
       case when p.Outcome is null
         then case when (select count(*)
                           from sitespecific.ProcessSecurity_APIBREAK ps
                          where ps.SecurityPrivilegeId = 7 -- Complete
                            and ps.ProcessId = p.ProcessId
                            and rownum <= 1) > 0
                then 'Y'
                else 'N'
              end
          else 'N'
       end  CanComplete
  from api.Processes p;
