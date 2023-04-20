CREATE OR REPLACE FORCE VIEW SITESPECIFIC.ASSIGNABLEPROCESSES
(PROCESSID, PROCESSTYPEID, SCHEDULEDSTARTDATE, JOBID, JOBTYPEPROCESSTYPEID, 
 OUTCOME)
BEQUEATH DEFINER
AS 
select distinct
  p.ProcessId,
  p.ProcessTypeId,
  p.ScheduledStartDate,
  p.JobId,
  p.JobTypeProcessTypeId,
  p.Outcome
from
  api.Processes p
  join api.ConfigSecurity cs
      on cs.SecurityClassId = 89  -- JobTypeProcessTypes
      /* Add 0 to the JobTypeProcessTypeId to prevent Oracle from using the
         JobTypeProcessId index (processes_ix_5) when retrieving the data from
         processes_t. That causes performance problems. */
      and cs.ConfigId = p.JobTypeProcessTypeId + 0
      and cs.PrivilegeName = 'Assign'
  join api.AccessGroupUsers agu
      on agu.AccessGroupId = cs.AccessGroupId
      and agu.AccessGroupId not in (1, 2)
      and agu.UserId = api.pkg_SecurityQuery.EffectiveUserId();


GRANT SELECT ON SITESPECIFIC.ASSIGNABLEPROCESSES TO POSSEEXTENSIONS;
