CREATE OR REPLACE package body SITESPECIFIC.pkg_WorkloadManager as

  subtype udt_Name is api.pkg_Definition.udt_Name;
  subtype udt_SearchResults is api.pkg_Definition.udt_SearchResults;

  g_AssignedUserIds                     api.udt_ObjectList;
  g_JobTypeIds                          api.udt_NumberTable;
  g_JobTypeProcessTypeIds               api.udt_NumberTable;
  g_ProcessTypeIds                      api.udt_NumberTable;

  /*---------------------------------------------------------------------------
   * LogProcedureCall() -- PRIVATE
   *   Log out the arguments of the procedure call.  This was extracted into a
   * separate procedure just to declutter the mainline procedure.
   *-------------------------------------------------------------------------*/
  procedure LogProcedureCall (
    a_RowLimit                          number,
    a_AssignedTo                        varchar2,
    a_Assigned                          udt_Boolean,
    a_Scheduled                         udt_Boolean,
    a_ScheduledStartDateFrom            date,
    a_ScheduledStartDateTo              date,
    a_ProcessTypeDescriptions           udt_StringList,
    a_JobExternalFileNum                varchar2,
    a_JobTypeDescription                varchar2
  ) is
  begin

    pkg_Debug.PutLine('pkg_WorkloadManager.WorkloadManagerProcessSearch');
    if a_RowLimit is not null then
      pkg_Debug.PutLine('  RowLimit: ' || a_RowLimit);
    end if;
    if a_AssignedTo is not null then
      pkg_Debug.PutLine('  AssignedTo: ' || a_AssignedTo);
    end if;
    if a_Assigned is not null then
      pkg_Debug.PutLine('  AssignedTo: ' || a_Assigned);
    end if;
    if a_Scheduled is not null then
      pkg_Debug.PutLine('  AssignedTo: ' || a_Scheduled);
    end if;
    if a_ScheduledStartDateFrom is not null then
      pkg_Debug.PutLine('  ScheduledStartDateFrom: '
          || to_char(a_ScheduledStartDateFrom,
              api.pkg_Definition.gc_DateFormat));
    end if;
    if a_ScheduledStartDateTo is not null then
      pkg_Debug.PutLine('  ScheduledStartDateTo: '
          || to_char(a_ScheduledStartDateTo,
              api.pkg_Definition.gc_DateFormat));
    end if;
    if a_ProcessTypeDescriptions.count() > 0 then
      pkg_Debug.PutLine('  ProcessTypes:');
      for i in 1..a_ProcessTypeDescriptions.count() loop
        pkg_Debug.PutLine('    ' || a_ProcessTypeDescriptions(i));
      end loop;
    end if;
    if a_JobExternalFileNum is not null then
      pkg_Debug.PutLine('  JobExternalFileNum: ' || a_JobExternalFileNum);
    end if;
    if a_JobTypeDescription is not null then
      pkg_Debug.PutLine('  JobTypeDescription: ' || a_JobTypeDescription);
    end if;

  end;

  /*---------------------------------------------------------------------------
   * ProcsByJobExternalFileNum() -- PRIVATE
   *   Find all the jobs by external file number contents, and then relate them
   * to the processes that match the process types.
   *-------------------------------------------------------------------------*/
  function ProcsByJobExternalFileNum (
    a_JobExternalFileNum                varchar2,
    a_SearchResults       in out nocopy udt_SearchResults
  ) return boolean is
    t_Index                             pls_integer := 0;
    t_JobIds                            udt_IdList;
    t_JobIdsTable                       api.udt_ObjectList;
    t_JobTypeName                       udt_Name;
    t_ProcessIds                        udt_IdList;
  begin

    t_JobIdsTable := api.udt_ObjectList();
    for jt in 1..g_JobTypeIds.count() loop
      select Name
      into t_JobTypeName
      from api.ObjectDefs
      where ObjectDefId = g_JobTypeIds(jt).Value;

      t_JobIds := api.pkg_Search.ObjectsByColumnContents(t_JobTypeName,
          'ExternalFileNum', a_JobExternalFileNum);
      if t_JobIds.count() > 0 then
        t_JobIdsTable.extend(t_JobIds.count());
        for i in 1..t_JobIds.count() loop
          t_Index := t_Index + 1;
          t_JobIdsTable(t_Index) := api.udt_Object(t_JobIds(i));
        end loop;
      end if;
    end loop;

    select /*+ CARDINALITY (jtpt 50) */ p.ProcessId
    bulk collect into t_ProcessIds
    from
      table(cast(t_JobIdsTable as api.udt_ObjectList)) j
      join AssignableProcesses p
          on p.JobId = j.ObjectId
          and p.Outcome is null
      join table(cast(g_JobTypeProcessTypeIds as api.udt_NumberTable)) jtpt
          on jtpt.Value = p.JobTypeProcessTypeId;

    return api.pkg_Search.IntersectList(t_ProcessIds, a_SearchResults);

  end;

  /*---------------------------------------------------------------------------
   * SetProcessAndJobTypes() -- PRIVATE
   *   Determine the job and process types to search on.  If the user has not
   * selected any process types or job types, we must assume all process types
   * that the current user has permission to Assign.
   *-------------------------------------------------------------------------*/
  procedure SetProcessAndJobTypes (
    a_ProcessTypeDescriptions           udt_StringList,
    a_JobTypeDescription                varchar2
  ) is
    t_JobTypeDescription                varchar2(60);
    t_JobTypeId                         udt_Id;
    t_JobTypeIds                        udt_IdList;
    t_JobTypeIdSparseArray              udt_IdList;
    t_JobTypeProcessTypeIds             udt_IdList;
    t_ProcessTypeDescriptions           api.udt_StringTable;
    t_ProcessTypeId                     udt_Id;
    t_ProcessTypeIds                    udt_IdList;
    t_ProcessTypeIdSparseArray          udt_IdList;
  begin

    t_JobTypeDescription := api.pkg_Utils.StandardizeForCompare(
        a_JobTypeDescription);

    if a_ProcessTypeDescriptions.count() > 0 then
      -- The user has specified some process type descriptions, so we start
      -- there.
      t_ProcessTypeDescriptions := api.udt_StringTable();
      t_ProcessTypeDescriptions.extend(a_ProcessTypeDescriptions.count());
      for i in 1..a_ProcessTypeDescriptions.count() loop
        t_ProcessTypeDescriptions(i)
            := api.udt_String(a_ProcessTypeDescriptions(i));
      end loop;

      select
        pt.ProcessTypeId,
        jt.ObjectDefId JobTypeId,
        jtpt.JobTypeProcessTypeId
      bulk collect into
        t_ProcessTypeIds,
        t_JobTypeIds,
        t_JobTypeProcessTypeIds
      from
        table(cast(t_ProcessTypeDescriptions as api.udt_StringTable)) ptd
        join api.ProcessTypes pt
            on pt.Description = ptd.Value
        join api.JobTypeProcessTypes jtpt
            on jtpt.ProcessTypeId = pt.ProcessTypeId
        join api.ObjectDefs jt
            on jt.ObjectDefId = jtpt.JobTypeId
            and (t_JobTypeDescription is null
                or api.pkg_Utils.StringContains(jt.Description,
                    t_JobTypeDescription) = 'Y')
            and exists (
                select *
                from
                  api.ConfigSecurity s
                  join api.AccessGroupUsers agu
                      on agu.AccessGroupId = s.AccessGroupId
                      and agu.UserId = api.pkg_SecurityQuery.EffectiveUserId()
                where s.SecurityClassId = 89 -- Job Type Process Types
                  and s.ConfigId = jtpt.JobTypeProcessTypeId
                  and PrivilegeName = 'Assign'
                  and agu.AccessGroupId != 2
                );

    elsif t_JobTypeDescription is not null then
      -- The user has specified at least part of a job type description, so we
      -- start there.
      select
        pt.ProcessTypeId,
        jt.JobTypeId,
        jtpt.JobTypeProcessTypeId
      bulk collect into
        t_ProcessTypeIds,
        t_JobTypeIds,
        t_JobTypeProcessTypeIds
      from
        api.JobTypes jt
        join api.JobTypeProcessTypes jtpt
            on jtpt.JobTypeId = jt.JobTypeId
        join api.ProcessTypes pt
            on pt.ProcessTypeId = jtpt.ProcessTypeId
      where api.pkg_Utils.StringContains(jt.Description,
          t_JobTypeDescription) = 'Y'
        and exists (
            select *
            from
              api.ConfigSecurity s
              join api.AccessGroupUsers agu
                  on agu.AccessGroupId = s.AccessGroupId
                  and agu.UserId = api.pkg_SecurityQuery.EffectiveUserId()
            where s.SecurityClassId = 89 -- Job Type Process Types
              and s.ConfigId = jtpt.JobTypeProcessTypeId
              and PrivilegeName = 'Assign'
              and agu.AccessGroupId != 2
            );

    else
      -- The user has not selected any process types or job types, so we must
      -- assume all that the current user has permission to assign.  There is
      -- no API to determine row types within a view.
      select
        jtpt.ProcessTypeId,
        jtpt.JobTypeId,
        jtpt.JobTypeProcessTypeId
      bulk collect into
        t_ProcessTypeIds,
        t_JobTypeIds,
        t_JobTypeProcessTypeIds
      from
        api.JobTypeProcessTypes jtpt
      where exists (
            select *
            from
              api.ConfigSecurity s
              join api.AccessGroupUsers agu
                  on agu.AccessGroupId = s.AccessGroupId
                  and agu.UserId = api.pkg_SecurityQuery.EffectiveUserId()
            where s.SecurityClassId = 89 -- Job Type Process Types
              and s.ConfigId = jtpt.JobTypeProcessTypeId
              and PrivilegeName = 'Assign'
              and agu.AccessGroupId != 2
            );
    end if;

    for i in 1..t_JobTypeIds.count() loop
      t_JobTypeIdSparseArray(t_JobTypeIds(i)) := null;
      t_ProcessTypeIdSparseArray(t_ProcessTypeIds(i)) := null;
    end loop;

    g_JobTypeIds := api.udt_NumberTable();
    g_ProcessTypeIds := api.udt_NumberTable();
    g_JobTypeProcessTypeIds := api.udt_NumberTable();

    t_JobTypeId := t_JobTypeIdSparseArray.first();
    while t_JobTypeId is not null loop
      g_JobTypeIds.extend(1);
      g_JobTypeIds(g_JobTypeIds.count()) := api.udt_Number(t_JobTypeId);

      t_JobTypeId := t_JobTypeIdSparseArray.next(t_JobTypeId);
    end loop;

    t_ProcessTypeId := t_ProcessTypeIdSparseArray.first();
    while t_ProcessTypeId is not null loop
      g_ProcessTypeIds.extend(1);
      g_ProcessTypeIds(g_ProcessTypeIds.count())
          := api.udt_Number(t_ProcessTypeId);

      t_ProcessTypeId := t_ProcessTypeIdSparseArray.next(t_ProcessTypeId);
    end loop;

    pkg_Debug.PutLine(t_JobTypeProcessTypeIds.count() || ' JTPTs:');
    g_JobTypeProcessTypeIds.extend(t_JobTypeProcessTypeIds.count());
    for i in 1..t_JobTypeProcessTypeIds.count() loop
      g_JobTypeProcessTypeIds(i) := api.udt_Number(t_JobTypeProcessTypeIds(i));
      pkg_Debug.PutLine('  ' || t_JobTypeProcessTypeIds(i));
    end loop;

  end;

  /*---------------------------------------------------------------------------
   * SetToDate() -- PRIVATE
   *   If a "to" date does not have a time portion, set the time to 23:59:59,
   * so that any dates matching the "to" date are found, even if they have a
   * time set.
   *-------------------------------------------------------------------------*/
  function SetToDate (
    a_Date                              date,
    a_DateName                          varchar2
  ) return date is
    t_Date                              date;
  begin

    if a_Date is not null and trunc(a_Date) = a_Date then
      t_Date := a_Date + 1 - 1 / (60 * 60 * 24);
      pkg_Debug.PutLine(a_DateName || ' has been set to '
          || to_char(t_Date, api.pkg_Definition.gc_DateFormat)
          || ' to allow for times.');
    else
      t_Date := a_Date;
    end if;

    return t_Date;

  end;

  /*---------------------------------------------------------------------------
   * SetUsers() -- PRIVATE
   *   Find the assigned users and put them in package state.
   *-------------------------------------------------------------------------*/
  procedure SetUsers (
    a_AssignedTo                        varchar2
  ) is
    t_UserIds                           udt_IdList;
    t_UserObjectDefName                 udt_Name;
  begin

    select od.Name
    into t_UserObjectDefName
    from
      api.Users u
      join api.ObjectDefs od
          on od.ObjectDefId = u.UserTypeId
    where u.UserId = api.pkg_SecurityQuery.EffectiveUserId();

    if a_AssignedTo is not null then
      t_UserIds := api.pkg_Search.ObjectsByColumnContents(t_UserObjectDefName,
          'Name', a_AssignedTo);
      g_AssignedUserIds := api.udt_ObjectList();
      g_AssignedUserIds.extend(t_UserIds.count());
      pkg_Debug.PutLine(t_UserIds.count() || ' Assigned UserIds:');
      for i in 1..t_UserIds.count() loop
        g_AssignedUserIds(i) := api.udt_Object(t_UserIds(i));
        pkg_Debug.PutLine('  ' || t_UserIds(i));
      end loop;
    end if;

  end;

  /*---------------------------------------------------------------------------
   * GetAssignedUserIds() -- PUBLIC
   *-------------------------------------------------------------------------*/
  function GetAssignedUserIds
  return api.udt_ObjectList is
  begin

    return g_AssignedUserIds;

  end;

  /*---------------------------------------------------------------------------
   * GetJobTypeProcessTypeIds() -- PUBLIC
   *-------------------------------------------------------------------------*/
  function GetJobTypeProcessTypeIds
  return api.udt_NumberTable is
  begin

    return g_JobTypeProcessTypeIds;

  end;

  /*---------------------------------------------------------------------------
   * WorkloadManagerProcessSearch() -- PUBLIC
   *   Perform a process search for the Workload Manager component.
   *-------------------------------------------------------------------------*/
  procedure WorkloadManagerProcessSearch (
    a_RowLimit                          number,
    a_AssignedTo                        varchar2,
    a_Assigned                          udt_Boolean,
    a_Scheduled                         udt_Boolean,
    a_ScheduledStartDateFrom            date,
    a_ScheduledStartDateTo              date,
    a_ProcessTypeDescriptions           udt_StringList,
    a_JobExternalFileNum                varchar2,
    a_JobTypeDescription                varchar2
  ) is
    t_ProcessIds                        udt_IdList;
    t_ScheduledStartDateTo              date;
    t_SearchResults                     udt_SearchResults;
    t_Sql                               varchar2(32767);

    c_LF                       constant char(1) := chr(10);
  begin

    if pkg_Debug.Enabled() = 'Y' and pkg_Debug.Suspended() = 'N' then
      LogProcedureCall(a_RowLimit, a_AssignedTo, a_Assigned,
          a_Scheduled, a_ScheduledStartDateFrom, a_ScheduledStartDateTo,
          a_ProcessTypeDescriptions, a_JobExternalFileNum,
          a_JobTypeDescription);
    end if;

    if a_AssignedTo is null
        and a_Assigned is null
        and a_Scheduled is null
        and a_ScheduledStartDateFrom is null
        and a_ScheduledStartDateTo is null
        and a_ProcessTypeDescriptions.count() = 0
        and a_JobExternalFileNum is null
        and a_JobTypeDescription is null then
      api.pkg_Errors.QueueBusinessError('You must enter some criteria.');
      return;
    end if;

    t_ScheduledStartDateTo := SetToDate(a_ScheduledStartDateTo,
        'ScheduledStartDateTo');

    if a_AssignedTo is not null then
      SetUsers(a_AssignedTo);
      if a_AssignedTo is not null and g_AssignedUserIds.count() = 0 then
        pkg_Debug.PutLine('No users exist that match the Assigned To '
            || 'criteria.');
        return;
      end if;
    end if;

    SetProcessAndJobTypes(a_ProcessTypeDescriptions, a_JobTypeDescription);

    if g_JobTypeProcessTypeIds.count() = 0 then
      pkg_Debug.PutLine('No processes exist that match the selected Process '
          || 'Type/Job Type combinations.');
      return;
    end if;

    t_SearchResults := api.pkg_Search.NewSearchResults();

    -- If the user has entered something in JobExternalFileNum, assume that
    -- it will be most efficient to search for jobs and get back all the
    -- processes that match the types.
    if a_JobExternalFileNum is not null then
      if not ProcsByJobExternalFileNum(a_JobExternalFileNum,
          t_SearchResults) then
        return;
      end if;
    end if;

    -- For the rest, generate dynamic SQL.  If a search was already done, and
    -- only Job Type and/or Process Type were entered (if even those), we don't
    -- need to do this part of the search.
    if not t_SearchResults.InitialSearchDone
        or a_ScheduledStartDateFrom is not null
        or a_ScheduledStartDateTo is not null
        or a_AssignedTo is not null then
      t_Sql :=
          'select ProcessId' || c_LF
          || 'from AssignableProcesses p' || c_LF
          || 'where JobTypeProcessTypeId in (' || c_LF
          || '    select /*+ CARDINALITY (jtpt 50) */ Value' || c_LF
          || '    from table(cast(' || c_LF
          || '        pkg_WorkloadManager.GetJobTypeProcessTypeIds()' || c_LF
          || '        as api.udt_NumberTable)) jtpt' || c_LF
          || '    )';

      if a_Scheduled = 'Y' then
        t_Sql := t_Sql || c_LF
            || ' and ScheduledStartDate is not null';
      elsif a_Scheduled = 'N' then
        t_Sql := t_Sql || c_LF
            || ' and ScheduledStartDate is null';
      end if;

      if a_ScheduledStartDateFrom is not null then
        t_Sql := t_Sql || c_LF
            || '  and ScheduledStartDate >= to_date('''
            || to_char(a_ScheduledStartDateFrom, api.pkg_Definition.gc_DateFormat)
            || ''', ''' || api.pkg_Definition.gc_DateFormat || ''')';
      end if;

      if a_ScheduledStartDateTo is not null then
        t_Sql := t_Sql || c_LF
            || '  and ScheduledStartDate <= to_date('''
            || to_char(t_ScheduledStartDateTo, api.pkg_Definition.gc_DateFormat)
            || ''', ''' || api.pkg_Definition.gc_DateFormat || ''')';
      end if;

      t_Sql := t_Sql || c_LF
            || ' and Outcome is null';

      if a_Assigned = 'Y' then
        t_Sql := t_Sql || c_LF
            || ' and exists (' || c_LF
            || '     select *' || c_LF
            || '     from api.IncompleteProcessAssignments' || c_LF
            || '     where ProcessId = p.ProcessId' || c_LF
            || '     )';
      elsif a_Assigned = 'N' then
        t_Sql := t_Sql || c_LF
            || ' and not exists (' || c_LF
            || '     select *' || c_LF
            || '     from api.IncompleteProcessAssignments' || c_LF
            || '     where ProcessId = p.ProcessId' || c_LF
            || '     )';
      end if;

      if a_AssignedTo is not null then
        t_Sql := t_Sql || c_LF
            || '  and exists (' || c_LF
            || '      select /*+ CARDINALITY(au 1) */ *' || c_LF
            || '      from' || c_LF
            || '        api.ProcessAssignments a' || c_LF
            || '        join table(cast(' || c_LF
            || '            pkg_WorkloadManager.GetAssignedUserIds()' || c_LF
            || '            as api.udt_ObjectList)) au' || c_LF
            || '            on au.ObjectId = a.UserId' || c_LF
            || '      where a.ProcessId = p.ProcessId' || c_LF
            || '      )';
      end if;
      pkg_Debug.PutLine('Generated SQL:');
      pkg_Debug.PutLine(t_Sql);
      execute immediate t_Sql
      bulk collect into t_ProcessIds;

      if not api.pkg_Search.IntersectList(t_ProcessIds, t_SearchResults) then
        return;
      end if;
    end if;

    api.pkg_Search.WriteSearchResults(t_SearchResults);

  end;

  /*---------------------------------------------------------------------------
   * AssignableStaffSearch()
   *   Perform a staff search for the Workload Manager component.
   *-------------------------------------------------------------------------*/
  procedure AssignableStaffSearch (
    a_RowLimit                          number
  ) as
  begin

    insert into
      api.SearchResults
    select
      au2.UserId
    from
      api.AccessGroupUsers au
      join api.ConfigSecurity cs
          on cs.AccessGroupId = au.AccessGroupId
          and cs.PrivilegeName = 'AssignTo'
      join api.AccessGroupUsers au2
          on au2.AccessGroupId = cs.ConfigId
    where
      au.UserId = api.pkg_SecurityQuery.EffectiveUserId()
      and au.AccessGroupId != 2 -- Exclude Super Users
      and au2.AccessGroupId != 2;

  end;

  /*---------------------------------------------------------------------------
   * GetAddOnData() -- PUBLIC
   *   Get the data needed for the Workload Manager Viewer addon.
   *-------------------------------------------------------------------------*/
  procedure GetAddOnData (
    a_WorkloadManagerObjectId           udt_Id,
    a_DaysToView                        number,
    a_AssigneeList                      out udt_Cursor,
    a_AssigneeDayList                   out udt_Cursor,
    a_TodayProcessCount                 out number,
    a_OverdueProcessCount               out number,
    a_PeriodProcessCount                out number,
    a_UnscheduledProcessCount           out number
  ) is
    t_Today                             date;
    t_PeriodEndDate                     date;
    t_StaffEndPointId                   number;
  begin

    -- Initialize the variables.
    t_Today := trunc(sysdate);
    t_PeriodEndDate := t_Today + a_DaysToView;
    t_StaffEndPointId := api.pkg_ConfigQuery.EndPointIdForName(
        'o_PosseWorkloadManager', 'Staff');

    -- Get a list of the assignees, including various process counts.
    open a_AssigneeList for
    select
      u.UserId,
      u.Name UserName,
      ( select count(distinct(ap.ProcessId))
        from api.IncompleteProcessAssignments ipa
        join AssignableProcesses ap
            on ap.ProcessId = ipa.ProcessId
        where ipa.AssignedTo = u.UserId
          and ap.ScheduledStartDate >= t_Today
          and ap.ScheduledStartDate < t_Today + 1
      ) TodayProcessCount,
      ( select count(distinct(ap.ProcessId))
        from api.IncompleteProcessAssignments ipa
        join AssignableProcesses ap
            on ap.ProcessId = ipa.ProcessId
        where ipa.AssignedTo = u.UserId
          and ap.ScheduledStartDate < t_Today
      ) OverdueProcessCount,
      ( select count(distinct(ap.ProcessId))
        from api.IncompleteProcessAssignments ipa
        join AssignableProcesses ap
            on ap.ProcessId = ipa.ProcessId
        where ipa.AssignedTo = u.UserId
          and ap.ScheduledStartDate >= t_Today
          and ap.ScheduledStartDate < t_PeriodEndDate
      ) PeriodProcessCount,
      ( select count(distinct(ap.ProcessId))
        from api.IncompleteProcessAssignments ipa
        join AssignableProcesses ap
            on ap.ProcessId = ipa.ProcessId
        where ipa.AssignedTo = u.UserId
          and ap.ScheduledStartDate is null
      ) UnscheduledProcessCount
    from
      api.Objects wm
      join api.Relationships sr
          on sr.FromObjectId = wm.ObjectId
          and sr.EndPointId = t_StaffEndPointId
      join api.Users u
          on u.UserId = sr.ToObjectId
    where wm.ObjectId = a_WorkloadManagerObjectId
    group by
      u.UserId,
      u.Name
    union all
    select
      -1 UserId,
      'Unassigned' UserName,
      nvl(sum( case
                 when p.ScheduledStartDate >= t_Today and p.ScheduledStartDate < t_Today + 1 then 1
                 else 0
               end
             ), 0) TodayProcessCount,
      nvl(sum( case
                 when p.ScheduledStartDate < t_Today then 1
                 else 0
               end
             ), 0) OverdueProcessCount,
      nvl(sum( case
                 when p.ScheduledStartDate >= t_Today and p.ScheduledStartDate < t_PeriodEndDate then 1
                 else 0
               end
             ), 0) PeriodProcessCount,
      nvl(sum( case
                 when p.ScheduledStartDate is null then 1
                 else 0
               end
             ), 0) UnscheduledProcessCount
    from
      dual,
      ( select ap.ScheduledStartDate
        from AssignableProcesses ap
        where ap.Outcome is null
          and not exists ( select *
                           from api.IncompleteProcessAssignments
                           where ProcessId = ap.ProcessId
                         )
      ) p;

    -- Get a list of the next 35 days (5 weeks) for each assignee, including
    -- the number of processes scheduled for each day. For the current date,
    -- include the overdue processes as well.
    open a_AssigneeDayList for
    select
      CalendarDate,
      sr.ToObjectId UserId,
      ( select count(distinct(ipa.ProcessId))
        from
          api.IncompleteProcessAssignments ipa
          join AssignableProcesses ap
              on ap.ProcessId = ipa.ProcessId
        where CalendarDate >= t_Today
          and ipa.AssignedTo = sr.ToObjectId
          and ((ap.ScheduledStartDate >= CalendarDate and ap.ScheduledStartDate < CalendarDate + 1)
              or (CalendarDate = t_Today and ap.ScheduledStartDate < CalendarDate))
      ) ScheduledProcessCount,
      case
        when CalendarDate >= t_Today and CalendarDate < t_PeriodEndDate then 'Y'
        else 'N'
      end IsInPeriod
    from ( select trunc(sysdate, 'DAY') + rownum - 1 CalendarDate
           from dual
           connect by rownum <= 35
         ),
      api.Objects wm
      join api.Relationships sr
          on sr.FromObjectId = wm.ObjectId
          and sr.EndPointId = t_StaffEndPointId
      where wm.ObjectId = a_WorkloadManagerObjectId
    union all
    select
      CalendarDate,
      -1 UserId,
      case
        when CalendarDate = t_Today then
          ( select count(distinct(ap.ProcessId))
            from AssignableProcesses ap
            where ap.ScheduledStartDate < CalendarDate + 1
              and ap.Outcome is null
              and not exists ( select *
                               from api.IncompleteProcessAssignments ipa
                               where ipa.ProcessId = ap.ProcessId
                             )
          )
        when CalendarDate > t_Today then
          ( select count(distinct(ap.ProcessId))
            from AssignableProcesses ap
            where ap.ScheduledStartDate >= CalendarDate
              and ap.ScheduledStartDate < CalendarDate + 1
              and ap.Outcome is null
              and not exists ( select *
                               from api.IncompleteProcessAssignments ipa
                               where ipa.ProcessId = ap.ProcessId
                             )
          )
        else 0
      end ScheduledProcessCount,
      case
        when CalendarDate >= t_Today and CalendarDate < t_PeriodEndDate then 'Y'
        else 'N'
      end IsInPeriod
    from ( select trunc(sysdate, 'DAY') + rownum - 1 CalendarDate
           from dual
           connect by rownum <= 35
         );

    -- Calculate the distinct process counts for Today, Overdue, Period, and
    -- Unscheduled.
    select
      sum( case
             when ScheduledStartDate >= t_Today and ScheduledStartDate < t_Today + 1 then 1
             else 0
           end
         ),
      sum( case
             when ScheduledStartDate < t_Today then 1
             else 0
           end
         ),
      sum( case
             when ScheduledStartDate >= t_Today and ScheduledStartDate < t_PeriodEndDate then 1
             else 0
           end
         ),
      sum( case
             when ScheduledStartDate is null then 1
             else 0
           end
         )
    into
      a_TodayProcessCount,
      a_OverdueProcessCount,
      a_PeriodProcessCount,
      a_UnscheduledProcessCount
    from ( select distinct
             ap.ProcessId,
             ap.ScheduledStartDate
           from
             api.IncompleteProcessAssignments ipa
             join AssignableProcesses ap
                 on ap.ProcessId = ipa.ProcessId
             join api.Users u
                 on u.UserId = ipa.AssignedTo
             join api.Relationships sr
                 on sr.FromObjectId = a_WorkloadManagerObjectId
                 and sr.ToObjectId = u.UserId
                 and sr.EndPointId = t_StaffEndPointId
           union all
           select ap.ProcessId,
                  ap.ScheduledStartDate
           from AssignableProcesses ap
           where ap.Outcome is null
             and not exists ( select *
                              from api.IncompleteProcessAssignments ipa
                              where ipa.ProcessId = ap.ProcessId
                            )
         );

  end;

end pkg_WorkloadManager;
/
