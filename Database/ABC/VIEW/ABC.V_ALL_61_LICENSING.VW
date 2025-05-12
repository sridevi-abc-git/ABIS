CREATE OR REPLACE FORCE VIEW ABC.V_ALL_61_LICENSING
(JOB_ID, ASSIGN_PID, PRIMARYLICENSEE, LICENSENUMBER, ASSIGN_TYPE, 
 ASSIGNSTAFFNAME, DUP_LICENSINGREPRESENTATIVE, PROCESS_TYPE, INVESTIGATION_NUMBER, STARTDATE, 
 COMPLETEDDATE, PROCESS_ID, PREMADDRESS1LINE, DISTRICTOFFICE)
BEQUEATH DEFINER
AS 
Select jl.Objectid  Job_ID,
         b.ObjectId   Assign_PID,  -- process ID could be for either assign, conduct or close
         api.pkg_ColumnQuery.VALUE (b.ObjectId, 'PrimaryLicensee') PrimaryLicensee,
         SUBSTR (api.pkg_ColumnQuery.VALUE (jl.ObjectId, 'LicenseNumber'), 1,40)  LicenseNumber,
         'LICENSING 61' Assign_type,
         api.pkg_ColumnQuery.VALUE (b.ObjectId, 'ASSIGNEDTONAME') AssignStaffName,
         (SELECT AttributeValue
             FROM possedata.ObjectColumnData d
            WHERE ObjectId = b.ObjectId AND ColumnDefId = 444086) dup_LicensingRepresentative,
         decode(b.ObjectDefID, 328431, 'Assign'  -- p_assignlicenseinvestigation
                             , 292578, 'Conduct' -- p_conductlicenseinvestigation
                             , 295343, 'Close') Process_type,
         b.ExternalFileNum Investigation_number,
         (SELECT StartDate  FROM posseaudit.LogicalTransactions
           WHERE LogicalTransactionId = b.CreatedLogicalTransactionId) StartDate,
         e.DateCompleted CompletedDate,
         jl.objectid process_id,
         SUBSTR (api.pkg_ColumnQuery.VALUE (b.ObjectId, 'PremAddress1Line'),1,200) PremAddress1Line,
         SUBSTR ( api.pkg_ColumnQuery.VALUE (b.ObjectId, 'DistrictOfficeCorral'),1,2)  DistrictOffice
     FROM objmodelphys.Objects b          -- p_assignlicenseinvestigation,  p_conductlicenseinvestigation,  p_closeinvestigation
    JOIN workflow.Processes e             --
      ON e.ProcessId = b.ObjectId         --
    JOIN possedata.ReadableObjects j   --
      ON j.ObjectId = e.JobId             --
    JOIN possedata.ReadableObjects jl  -- query.j_license
      ON jl.objectid = e.Jobid            --
    JOIN workflow.jobs ejl                --
      ON ejl.JobId = jl.ObjectId          --
   WHERE b.ObjectDefID in (328431,292578, 295343)   -- p_assignlicenseinvestigation,  p_conductlicenseinvestigation,  p_closeinvestigation
    and jl.ObjectDefId = 325227;


GRANT SELECT ON ABC.V_ALL_61_LICENSING TO PUBLIC;
