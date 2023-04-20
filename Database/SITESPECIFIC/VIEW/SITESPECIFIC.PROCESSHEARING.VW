CREATE OR REPLACE FORCE VIEW SITESPECIFIC.PROCESSHEARING
(JOBID, PROCESSID, EXTERNALFILENUM, ACCUSATIONDATE, COMPANYNAME, 
 DBA, DISTRICTOFFICENAME, FNAME, HEARINGADDRESS, HEARINGDATE, 
 HEARINGHOURS, HEARINGTIME, LNAME, LEGALPHONENUMBER, LICENSENO, 
 LICENSETYPES, MNAME, PREMISESADDRESS, REGNO, SNAME, 
 SLNAME, SMNAME, TNAME, TLNAME, TMNAME, 
 TYPELICENSE, TYPEOFAPPLICATION)
BEQUEATH DEFINER
AS 
select j.JobId,
         p.ProcessId,
         j.ExternalFileNum,
         p.CreatedDate AccusationDate,
         nvl(api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'PrimaryCompanyLicensee'), api.pkg_columnquery.Value(j.JobId, 'PrimaryCompanyApplicant')) CompanyName,
         nvl(api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'PrimaryDBA'), api.pkg_columnquery.Value(j.JobId, 'PrimaryDBA')) DBA,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'BaseFileOfficeId'), api.pkg_columnquery.Value(j.JobId, 'OfficeId')), 'OfficeName') DistrictOfficeName,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'FirstApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'FirstLicenseeId')), 'FirstName') FName,
         replace(api.pkg_columnquery.Value(p.ProcessId, 'ProceedingLocation'), CHR(13)||CHR(10) , ', ') HearingAddress,
         api.pkg_columnquery.Value(p.ProcessId, 'ScheduledHearingDate') HearingDate,
         api.pkg_columnquery.Value(p.ProcessId, 'EstimatedHearingHours') HearingHours,
         api.pkg_columnquery.Value(p.ProcessId, 'ScheduledHearingTime') HearingTime,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'FirstApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'FirstLicenseeId')), 'LastName') LName,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'BaseFileOfficeId'), api.pkg_columnquery.Value(j.JobId, 'OfficeId')), 'OfficePhoneNumber') LegalPhoneNumber,
         api.pkg_columnquery.Value(j.JobId, 'LicenseNumber') LicenseNo,
         api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LastRegisterProtestId'), 'ApplicableLTDescription')LicenseTypes,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'FirstApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'FirstLicenseeId')), 'MiddleName') MName,
        nvl(api.pkg_ColumnQuery.Value(api.pkg_ColumnQuery.Value(j.JobId, 'PremisesAddressObjectId'), 'FMPFormattedAddress'), api.pkg_ColumnQuery.Value(api.pkg_ColumnQuery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'PremisesAddressObjectId'), 'FMPFormattedAddress')) PremisesAddress,
         nvl(api.pkg_columnquery.Value(j.JobId, 'RegNumber'), (case when api.pkg_columnquery.Value(j.JobId, 'ObjectDefName') = 'j_Accusation'
                                                                    then j.ExternalFileNum
                                                               end)) RegNo,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'SecondApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'SecondLicenseeId')), 'FirstName') SName,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'SecondApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'SecondLicenseeId')), 'LastName') SLName,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'SecondApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'SecondLicenseeId')), 'MiddleName') SMName,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'ThirdApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'ThirdLicenseeId')), 'FirstName') TName,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'ThirdApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'ThirdLicenseeId')), 'LastName') TLName,
         api.pkg_columnquery.Value(nvl(api.pkg_columnquery.Value(j.JobId, 'ThirdApplicantId'), api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LicenseJobId'), 'ThirdLicenseeId')), 'MiddleName') TMName,
         api.pkg_columnquery.Value(api.pkg_columnquery.Value(j.JobId, 'LastRegisterProtestId'), 'ApplicableLicenseType') TypeLicense,
         api.pkg_columnquery.value(j.JobId, 'ApplicationType') TypeofApplication
    from api.jobs j
    join api.processes p
      on p.JobId = j.JobId
    join api.processtypes pt
      on p.ProcessTypeId = pt.ProcessTypeId
   where pt.Name = 'p_ProcessHearing';
