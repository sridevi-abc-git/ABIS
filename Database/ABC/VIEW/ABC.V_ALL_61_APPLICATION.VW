CREATE OR REPLACE FORCE VIEW ABC.V_ALL_61_APPLICATION
(JOB_ID, ASSIGN_PID, PRIMARYLICENSEE, LICENSENUMBER, ASSIGN_TYPE, 
 ASSIGNSTAFFNAME, DUP_LICENSINGREPRESENTATIVE, PROCESS_TYPE, INVESTIGATION_NUMBER, STARTDATE, 
 COMPLETEDDATE, PROCESS_ID, PREMADDRESS1LINE, DISTRICTOFFICE)
BEQUEATH DEFINER
AS 
Select jl.Objectid  Job_ID,
         b.ObjectId   Assign_PID,  -- process ID could be for either assign, conduct or close
         api.pkg_ColumnQuery.VALUE (b.ObjectId, 'PrimaryLicensee') PrimaryLicensee,
         SUBSTR (api.pkg_ColumnQuery.VALUE (jl.ObjectId, 'LicenseNumber'), 1,40)  LicenseNumber,
         'ADMIN 61' Assign_type,
         api.pkg_ColumnQuery.VALUE (b.ObjectId, 'AssignStaffName') AssignStaffName,
         (SELECT AttributeValue
             FROM possedata.ObjectColumnData d
            WHERE ObjectId = b.ObjectId AND ColumnDefId = 444086) dup_LicensingRepresentative,
         decode(b.ObjectDefID, 329421, 'Assign'  -- P_ASSIGNADMININVESTIGATION
                             , 303706, 'Conduct' -- P_CONDUCTADMININVESTIGATION
                             , 295343, 'Close') Process_type,
         b.ExternalFileNum Investigation_number,
         (SELECT StartDate  FROM posseaudit.LogicalTransactions
           WHERE LogicalTransactionId = b.CreatedLogicalTransactionId) StartDate,
         e.DateCompleted CompletedDate,
         jl.objectid process_id,
         SUBSTR (api.pkg_ColumnQuery.VALUE (jl.ObjectId, 'PremAddress1Line'),1,200) PremAddress1Line,
         SUBSTR ( api.pkg_ColumnQuery.VALUE (jl.ObjectId, 'BASEFILEOFFICECORRAL'),1,2)  DistrictOffice
     FROM objmodelphys.Objects b          -- p_assignlicenseinvestigation,  p_conductlicenseinvestigation,  p_closeinvestigation
    JOIN workflow.Processes e             --
      ON e.ProcessId = b.ObjectId         --
    JOIN possedata.ReadableObjects j   --
      ON j.ObjectId = e.JobId             --
    JOIN possedata.ReadableObjects jl  -- query.j_Application
      ON jl.objectid = e.Jobid            --
    JOIN workflow.jobs ejl                --
      ON ejl.JobId = jl.ObjectId          --
   WHERE b.ObjectDefID in (329421,303706, 295343)   -- P_ASSIGNADMININVESTIGATION,  P_CONDUCTADMININVESTIGATION,  p_closeinvestigation
    and jl.ObjectDefId = 338587;


GRANT SELECT ON ABC.V_ALL_61_APPLICATION TO PUBLIC;
