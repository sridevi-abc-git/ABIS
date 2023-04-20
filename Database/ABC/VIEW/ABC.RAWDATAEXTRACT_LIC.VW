CREATE OR REPLACE FORCE VIEW ABC.RAWDATAEXTRACT_LIC
(JOBID, APP_OR_LIC, LICENSENO, FILESTATUSCODE, FILESTATUSDATE, 
 OFFICENO, OFFICENAME, LICENSETYPES, TYPESTATUS, TYPEMASTERIND, 
 TYPESTATUSDATE, TYPEORIGISSUEDATE, TYPEEXPIREDATE, TYPEFEECODE, TYPETRANSFERFROM, 
 TYPETRANSFERTO, ACTIVEDBA, PRIMARYLICENSEE, PREMISESADDRESSCOMBINED, PREMADDRESSLINE1, 
 PREMADDRESSLINE2, PREMADDRESSLINE3, PREMCITY, PREMSTATE, PREMZIP, 
 PREMCENSUSTRACT, PREMGEOCODE, MAILINGADDRESSCOMBINED, MAILADDRESSLINE1, MAILADDRESSLINE2, 
 MAILADDRESSLINE3, MAILADDRESSCITY, MAILADDRESSSTATE, MAILZIPCODE)
BEQUEATH DEFINER
AS 
SELECT j.jobid, 'LIC' app_or_lic,
          j.externalfilenum licenseno,
          j.STATUSNAME FileStatusCode,
          Null FileStatusDate,
          substr( o.office, 0, 2 ) officenumber, o.office officename,
         mart.getltcodesforlicense (j.jobid) licensetypes,
         
         ABC.GetMart_CNCT_LicTypStatCode (j.jobid) TypeStatus,
         ABC.GetMart_CNCT_LicTypMI (j.jobid) MasterInd,
         ABC.GetMart_CNCT_LicTypStatDate (j.jobid) TypeStatusDate,
         ABC.GetMart_CNCT_LicTypIssueDate (j.jobid) TypeOrigIssueDate,
         ABC.GetMart_CNCT_LicTypExpDate (j.jobid) TypeExpireDate,
         ABC.GetMart_CNCT_LicTypFeeCode (j.jobid) TypeFeeCode,
         
 --         mart.getltnamesforlicense (j.jobid) licensetypedescriptions,
 --         mart.getlicenselegalentity (j.jobid, 'N', 1) companyname,
  --        mart.getformattedaddress (ma.objectid) mailingaddressCombined,
          null TypeTransferFrom,
          null TypeTransferTo,
          
          d.activedba ActiveDBA,
          j.PrimaryLicensee,
          mart.getformattedaddress (bl.addressobjectid) premisesaddressCombined,
          ABC.GETMART_PREMADDLINE1 (j.jobid) PremAddressLine1,
          ABC.GETMART_PREMADDLINE2 (j.jobid) PremAddressLine2,
          ABC.GETMART_PREMADDLINE3 (j.jobid) PremAddressLine3,
          ABC.GETMART_PREMCITY     (j.jobid) PremCity,
          ABC.GETMART_PREMSTATE    (j.jobid) PremState,
          ABC.GETMART_PREMZIP      (j.jobid) PremZip,
          ABC.GETMART_PremCensusTract  (j.jobid) PremCensusTract,
          ABC.GETMART_PremGeoCode      (j.jobid) PremGeoCode, 
          mart.getformattedaddress (ma.objectid) mailingaddressCombined,
          ma.ADDRESSLINE1 MailAddressLine1,
          ma.ADDRESSLINE2 MailAddressLine2,
          ma.ADDRESSLINE2 MailAddressLine3,
          ma.USACITY MailAddressCity,
          ma.USASTATECODE MailAddressState,
          ma.ZIPCODE || Decode(ma.ZIPEXTENSION, null, '', '-')|| ma.ZIPEXTENSION MailZipCode

     FROM mart.license j LEFT OUTER JOIN mart.licensedba ld ON ld.licensejobid = j.jobid
          LEFT OUTER JOIN mart.dbanames d ON d.objectid = ld.dbaobjectid
          LEFT OUTER JOIN mart.office o ON j.basefileofficeid = o.objectid
          LEFT OUTER JOIN mart.businesslocations bl 
          ON bl.jobobjectid = j.jobid
          LEFT OUTER JOIN mart.businessmailinglocations bml
          ON bml.jobobjectid = j.jobid
          LEFT OUTER JOIN mart.address ma ON ma.objectid = bml.addressobjectid 
          -- *** Added to filter Liscense type status in where clause
          Left Outer Join MART.LICENSETYPE mlt on MLT.LICENSEJOBID = j.jobid
                   
   WHERE (d.primarydba = 'Y' OR d.objectid IS NULL)
   -- *** Added to filter Liscense type status in where clause
   and MLT.STATUSNAME in ('ACTIVE', 'SLMSHD', 'SUSPEN', 'REVPEN', 'SUREND', 'R64B', 'PEND')
   and MLT.LICENSETYPECODE not between '30' and '39';


GRANT SELECT ON ABC.RAWDATAEXTRACT_LIC TO POSSEEXTENSIONS;

GRANT SELECT ON ABC.RAWDATAEXTRACT_LIC TO PUBLIC;
