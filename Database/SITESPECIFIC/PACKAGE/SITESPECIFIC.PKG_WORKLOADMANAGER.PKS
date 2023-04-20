CREATE OR REPLACE package SITESPECIFIC.pkg_WorkloadManager as

  /*---------------------------------------------------------------------------
   * DESCRIPTION
   *   Routines needed for the Workload Manager business component.
   *-------------------------------------------------------------------------*/

  type udt_Cursor is ref cursor;
  subtype udt_Boolean is api.pkg_Definition.udt_Boolean;
  subtype udt_Id is api.pkg_Definition.udt_Id;
  subtype udt_IdList is api.pkg_Definition.udt_IdList;
  subtype udt_StringList is api.pkg_Definition.udt_StringList;

  /*---------------------------------------------------------------------------
   * GetAssignedUserIds()
   *   Return the assigned user Ids.
   *-------------------------------------------------------------------------*/
  function GetAssignedUserIds
  return api.udt_ObjectList;

  /*---------------------------------------------------------------------------
   * GetJobTypeProcessTypeIds()
   *   Return the JobTypeProcessTypeIds.
   *-------------------------------------------------------------------------*/
  function GetJobTypeProcessTypeIds
  return api.udt_NumberTable;

  /*---------------------------------------------------------------------------
   * WorkloadManagerProcessSearch()
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
  );

  /*---------------------------------------------------------------------------
   * AssignableStaffSearch()
   *   Perform a staff search for the Workload Manager component.
   *-------------------------------------------------------------------------*/
  procedure AssignableStaffSearch (
    a_RowLimit                        number
  );

  /*---------------------------------------------------------------------------
   * GetAddOnData()
   *   Get the data needed for the Workload Manager Viewer addon.
   *-------------------------------------------------------------------------*/
  procedure GetAddOnData (
    a_WorkloadManagerObjectId   udt_Id,
    a_DaysToView                number,
    a_AssigneeList              out udt_Cursor,
    a_AssigneeDayList           out udt_Cursor,
    a_TodayProcessCount         out number,
    a_OverdueProcessCount       out number,
    a_PeriodProcessCount        out number,
    a_UnscheduledProcessCount   out number
  );

end pkg_WorkloadManager;
/
