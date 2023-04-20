CREATE OR REPLACE FORCE VIEW SITESPECIFIC.PROCESSSECURITY_APIBREAK
(PROCESSID, SECURITYPRIVILEGEID)
BEQUEATH DEFINER
AS 
select
  p.ProcessId,
  i.SecurityPrivilegeId
from workflow.Processes p
join workflow.jobs j  on j.JobId = p.JobId
join workflow.JobTypeProcessTypes jtpt  on jtpt.JobTypeId = j.JobTypeId and jtpt.ProcessTypeId = p.ProcessTypeId
join security.InstanceSecurity i   on i.ClassId = 89 and i.InstanceId = jtpt.JobTypeProcessTypeId
join security.AccessGroupUsers au   on au.AccessGroupId = i.AccessGroupId and au.UserId = api.Pkg_Securityquery.EffectiveUserId;
