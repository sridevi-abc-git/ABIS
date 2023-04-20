CREATE OR REPLACE FORCE VIEW ABC.V_ALL_61_ENFORCEMENT
(JOB_ID, ASSIGN_PID, PRIMARYLICENSEE, LICENSENUMBER, ASSIGN_TYPE, 
 ASSIGNSTAFFNAME, INVESTIGATOR, DUP_LICENSINGREPRESENTATIVE, PROCESS_TYPE, INVESTIGATION_NUMBER, 
 STARTDATE, COMPLETEDDATE, PROCESS_ID, PREMADDRESS1LINE, DISTRICTOFFICE, 
 ADMINISTRATIVETYPE)
BEQUEATH DEFINER
AS 
SELECT
  JL.Objectid Job_ID,
  b.ObjectId Assign_PID, -- process ID could be for either assign, conduct or close
  api.pkg_ColumnQuery.VALUE (b.ObjectId, 'PrimaryLicensee') PrimaryLicensee,
  SUBSTR (api.pkg_ColumnQuery.VALUE (JL.ObjectId, 'LicenseNumber'),1,40) LicenseNumber,
  
  SUBSTR (
    ( SELECT NVL (v.VALUE, d.AttributeValue)
        FROM possedata.ObjectColumnData  d
      LEFT JOIN objmodelphys.AllDomainListOfValues v ON v.ListValueId = d.AttributeValueId
      WHERE d.ObjectId = JL.ObjectId AND d.ColumnDefId = 331023
    ), 
    1, 100
  ) Assign_type,

 SUBSTR (api.pkg_ColumnQuery.VALUE (b.ObjectId, 'PrimaryInvestigator'), 1, 60) AssignStaffName,
  api.pkg_ColumnQuery.VALUE (b.ObjectId, 'Investigator') Investigator,
  ( SELECT AttributeValue
      FROM possedata.ObjectColumnData d
     WHERE ObjectId = b.ObjectId AND ColumnDefId = 444086
  ) dup_LicensingRepresentative,

/* DECODE Deprecated by Oracle DECODE 
  DECODE (
    b.ObjectDefID,
    325300, 'Assign',                   -- P_ASSIGNINVESTIGATION
    313181, 'Conduct',                   -- P_CONDUCTENFORCEMENTINV
    295343, 'Close'
  ) Process_type_x,
*/
  CASE b.ObjectDefID
  WHEN 325300 THEN 'Assign'                   -- P_ASSIGNINVESTIGATION
  WHEN 313181 THEN 'Conduct'                  -- P_CONDUCTENFORCEMENTINV
  WHEN 295343 THEN 'Close'
  END Process_type,

  SUBSTR (api.pkg_ColumnQuery.VALUE (b.ObjectId, 'InvestigationNumber'), 1, 50) Investigation_number,
  ( SELECT StartDate
      FROM posseaudit.LogicalTransactions
      WHERE LogicalTransactionId = b.CreatedLogicalTransactionId
  ) StartDate,

  e.DateCompleted CompletedDate,
  JL.objectid process_id,
  SUBSTR (api.pkg_ColumnQuery.VALUE (JL.ObjectId, 'PremAddress1Line'), 1, 200) PremAddress1Line,
  SUBSTR (api.pkg_ColumnQuery.VALUE (JL.ObjectId, 'INVESTIGATIONOFFICECORRAL'), 1, 2) DistrictOffice,
  SUBSTR (api.pkg_ColumnQuery.VALUE (JL.ObjectId, 'ADMINISTRATIVETYPE'), 1, 100) AdministrativeType
 
FROM objmodelphys.Objects  b --  P_ASSIGNINVESTIGATION,  P_CONDUCTENFORCEMENTINV,  p_closeinvestigation
JOIN workflow.Processes e ON e.ProcessId = b.ObjectId             
JOIN possedata.ReadableObjects j ON j.ObjectId = e.JobId           
JOIN possedata.ReadableObjects JL ON JL.objectid = e.Jobid  --query.j_investigation
JOIN workflow.jobs ejl ON eJL.JobId = JL.ObjectId         
WHERE b.ObjectDefID IN (325300, 313181, 295343) -- P_ASSIGNINVESTIGATION,  P_CONDUCTENFORCEMENTINV,  P_CLOSEINVESTIGATION
AND JL.ObjectDefId = 333515;


GRANT SELECT ON ABC.V_ALL_61_ENFORCEMENT TO PUBLIC;
