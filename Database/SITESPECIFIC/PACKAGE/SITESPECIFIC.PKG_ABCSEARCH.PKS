CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_abcsearch
IS
    -- **************************************************************************
    -- File:        PKG_ABCSEARCH.pks
    -- Author:      CX
    --
    -- $Rev: 381 $
    -- $Date: 2019-11-09 06:21:27 -0800 (Sat, 09 Nov 2019) $
    -- Last Changed By:  $Author: TLord $
    --
    -- Note: Changed in dev environment on 2021-12-09 by Samuel Fehr.
    --       See history below.   
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         	Initial Check-in
    -- 03/08/2018 TJL 			WO13579  Added missing procedure for P12A	
  	-- 10/17/2018 NW 			W0 15584 Truncated SSN causes search problem in FINDPERSON. 
    --                          Changed a_socialsecuritynumber to VARCHAR2, original declared as NUMERIC
    -- 12/10/2018 NW            Delete changes made for WO13579 	
    -- 03/15/2019 PK            WO 13953 Added Search Functionality For Impact Inspections    
	-- 07/24/2019 TJL  WO 17980 Added new search procedure findpaymenttransunearned
    -- 12/09/2021 SF(CX)        Added wrapper procedure for findpaymenttransunearned so it can be used by the new StaffUI system.
    -- 05/01/2024 PK   WO35704  Added LSPID to search screen Caterer/Event Auth Search
    -- 03/23/2026  PK   1037    ABIS Search - Adding Address Line 2 tp Procedure FindLicenseandApplication
    -- 03/24/2026  PK   1037    ABIS Search - Adding Address Line 2 tp Procedure FindPerson
    -- 03/26/2026  Sri  1037    ABISCompany Search - Adding Address Line 2 tp Procedure FindCompany
    -- 04/08/2026  Sri  1037    ABISAttorney Search - Adding Address Line 2 tp Procedure FindAttorney
    -- 04/13/2026  Sri  1037    ABISLicenseType Search - Adding Address Line 2 tp Procedure FindLicenseType
    -- 04/17/2026  Sri  1037    ABISOneDay LicenseSearch - Adding Address Line 2 tp Procedure FindOneDayLicense
    -- 04/20/2026  Sri  1037    ABIScaterer/Event AuthSearch - Adding Address Line 2 tp Procedure findcaterereventauths




    
    -- **************************************************************************

    /*------------------------------------------------------------------------*
     * Types declaration
     *------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    ---------------------------------------------------------
    --  FindUserOffices() -- PUBLIC
    --  Used by FindABC19Monthly and FindUserProcesses
    ---------------------------------------------------------
    PROCEDURE finduseroffices(a_userid              udt_id,
                              a_validofficeidlist IN OUT udt_idlist);

    /**************************************************************************************************
     * FindABC19Monthly() -- PUBLIC
     *   Search for for ABC-19 Monthly Objects
     * Updated 10/23/2015 by Andy Patterson for performance
     **************************************************************************************************/
    PROCEDURE findabc19monthly(a_dup_monthnumber  NUMBER,
                               a_year             NUMBER,
                               a_dup_districtoffice NUMBER,
                               a_objects      OUT api.udt_objectlist);

    PROCEDURE findaccessgroups(
        a_description                VARCHAR2,
        a_excludeobjectids           VARCHAR2,
        a_objectlist      OUT NOCOPY api.udt_objectlist);

    PROCEDURE findaccusation(a_status                     VARCHAR2,
                             a_createddate                DATE,
                             a_createddateupper           DATE,
                             a_externalfilenum            VARCHAR2,
                             a_licensenumber              VARCHAR2,
                             a_currentobjectids           VARCHAR2,
                             a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findactivesuspendedlicense(
        a_externalfilenum            VARCHAR2,
        a_licenseenames              VARCHAR2,
        a_dup_premaddressline1       VARCHAR2,
        a_dup_premaddressuscity      VARCHAR2,
        a_dup_premzipcode            VARCHAR2,
        a_dup_dbas                   VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findaddress(a_addressline1               VARCHAR2,
                          a_addressline2               VARCHAR2,
                          a_usacity                    VARCHAR2,
                          a_usastate                   VARCHAR2,
                          a_zipcode                    VARCHAR2,
                          a_country                    VARCHAR2,
                          a_censustract                NUMBER,
                          a_addresskeywords            VARCHAR2,
                          a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                          a_objects         OUT NOCOPY api.udt_objectlist);

    ----------------------------------------------------------------------------------------------------
    --  FindApplication() -- PUBLIC
    -- Used by Outrider to Search for Applications
    ----------------------------------------------------------------------------------------------------

    PROCEDURE findapplication(
        a_externalfilenum            VARCHAR2,
        a_primarylicensee            VARCHAR2,
        a_premaddressline1           VARCHAR2,
        a_premuscity                 VARCHAR2,
        a_premzipcode                VARCHAR2,
        a_dup_dbas                   VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_status                     VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findattorney(a_lastname                   VARCHAR2,
                           a_firstname                  VARCHAR2,
                           a_firmname                   VARCHAR2,
                           a_addressline1               VARCHAR2,
                           a_addressline2               VARCHAR2,
                           a_city                       VARCHAR2,
                           a_state                      VARCHAR2,
                           a_zipcode                    VARCHAR2,
                           a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                           a_objects         OUT NOCOPY api.udt_objectlist);

    ---------------------------------------------------------------------------------------------------
    PROCEDURE findbeerkegtags(
        a_tagnumber                  VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findbranchlicensetype(
        a_licenseexternalfilenum     VARCHAR2,
        a_licenseenames              VARCHAR2,
        a_licenseaddressline1        VARCHAR2,
        a_licenseuscity              VARCHAR2,
        a_licensezipcode             VARCHAR2,
        a_licensedbas                VARCHAR2,
        a_fromprimarylicensetype     NUMBER,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findbranchprimarylicensetype(
        a_licenseexternalfilenum     VARCHAR2,
        a_licenseenames              VARCHAR2,
        a_licenseaddressline1        VARCHAR2,
        a_licenseuscity              VARCHAR2,
        a_licensezipcode             VARCHAR2,
        a_licensedbas                VARCHAR2,
        a_fromprimarylicensetype     NUMBER,
        a_objects         OUT NOCOPY api.udt_objectlist);

    /**************************************************************************************************
     * FindCompany() -- PUBLIC
     *   Search for Company Objects
     * Updated 10/23/2015 by Ryan Lutz for performance
     **************************************************************************************************/
    PROCEDURE findcompany(a_companyname                VARCHAR2,
                          a_addressline1               VARCHAR2,
                          a_addressline2               VARCHAR2,     --Added by sri
                          a_uscity                     VARCHAR2,
                          a_usstate                    VARCHAR2,
                          a_zipcode                    VARCHAR2,
                          a_keywords                   VARCHAR2,
                          a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                          a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE finddishonorpayments(
        a_externalfilenum            VARCHAR2,
        a_batchdate                  DATE,
        a_batchdateupper             DATE,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_completeddate              DATE,
        a_completeddateupper         DATE,
        a_status                     VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findescrow(a_escrowcompanyname          VARCHAR2,
                         a_addressline1               VARCHAR2,
                         a_uscity                     VARCHAR2,
                         a_usstate                    VARCHAR2,
                         a_zipcode                    VARCHAR2,
                         a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findfees(a_jobnumber                  VARCHAR2,
                       a_objects         OUT NOCOPY api.udt_objectlist);

    -------------------------------------
    PROCEDURE findfilteredcatererevent(
        a_objectid                   NUMBER,
        a_startdate                  DATE,
        a_enddate                    DATE,
        a_objects         OUT NOCOPY api.udt_objectlist);

    ---------------------------------------------
    PROCEDURE findfilteredfees(
        a_jobid                      udt_id,
        a_startdate                  DATE,
        a_enddate                    DATE,
        a_cataepa                    VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE feesforfiltering(
        a_jobid                      udt_id,
        a_startdate                  DATE,
        a_enddate                    DATE,
        a_cataepa                    VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    ----------------------------------
    PROCEDURE findfilteredonedaylicenses(
        a_objectid                   NUMBER,
        a_startdate                  DATE,
        a_enddate                    DATE,
        a_objects         OUT NOCOPY api.udt_objectlist);

    ----------------------------------

    PROCEDURE findfilteredpayments(
        a_jobid                      udt_id,
        a_startdate                  DATE,
        a_enddate                    DATE,
        a_cataepa                    VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findfilteredpaytrans(
        a_jobid                      udt_id,
        a_startdate                  DATE,
        a_enddate                    DATE,
        a_cataepa                    VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findhold(a_holdcomment                VARCHAR2,
                       a_holdtype                   VARCHAR2,
                       a_createddate                DATE,
                       a_createddateupper           DATE,
                       a_holduntil                  DATE,
                       a_holduntilto                DATE,
                       a_holdreleased               DATE,
                       a_holdreleasedto             DATE,
                       a_createdby                  VARCHAR2,
                       a_holdstatus                 VARCHAR2,
                       a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findinvestigation(
        a_investigationnumber        VARCHAR2,
        a_abcreportnumber            VARCHAR2,
        a_citationnumber             VARCHAR2,
        a_investigationtype          VARCHAR2,
        a_violationtype              VARCHAR2,
        a_administrativetype         VARCHAR2,
        a_name                       VARCHAR2,
        a_licensenumber              VARCHAR2,
        a_unlicensed                 VARCHAR2,
        a_addressline1               VARCHAR2,
        a_city                       VARCHAR2,
        a_state                      VARCHAR2,
        a_zipcode                    VARCHAR2,
        a_status                     VARCHAR2,
        a_createdstartdate           DATE,
        a_createdenddate             DATE,
        a_completedstartdate         DATE,
        a_completedenddate           DATE,
        a_arrestfirstname            VARCHAR2, -- 6/8/2014 Added by Sheik for WO#9446 Search by Arrest Names
        a_arrestlastname             VARCHAR2, -- 6/8/2014 Added by Sheik for WO#9446 Search by Arrest Names
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findjobpayment(a_dup_licensenumber          VARCHAR2,
                             a_paymentdate                DATE,
                             a_paymentdateupper           DATE,
                             a_dup_receiptnumber          VARCHAR2,
                             a_batchid                    VARCHAR2,
                             a_objectdefname              VARCHAR2,
                             a_objects         OUT NOCOPY api.udt_objectlist);


    /**************************************************************************************************
     * FindLegalEntity() -- PUBLIC
     *   Called by Outrider to find Legal Entity objects
     * Updated 10/23/2015 by Ryan Lutz for performance
     **************************************************************************************************/
    PROCEDURE findlegalentity(
        a_name                       VARCHAR2,
        a_addressline1               VARCHAR2,
        a_uscity                     VARCHAR2,
        a_usstate                    VARCHAR2,
        a_zipcode                    NUMBER,
        a_relatedjoblicno            VARCHAR2,
        a_hierarchylevel             VARCHAR2,
        a_socialsecurityno           VARCHAR2, --NUMBER,
        a_objects         OUT NOCOPY api.udt_objectlist);

    /**************************************************************************************************
     * FindLegalEntityNonP12() -- PUBLIC
     *   Called by Outrider to find Legal Entity objects which are not P12 entities
     * Created 10/23/2015 by Daniel Magill
     **************************************************************************************************/
    PROCEDURE findlegalentitynonp12(
        a_name                       VARCHAR2,
        a_addressline1               VARCHAR2,
        a_uscity                     VARCHAR2,
        a_usstate                    VARCHAR2,
        a_zipcode                    NUMBER,
        a_relatedjoblicno            VARCHAR2,
        a_hierarchylevel             VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    ----------------------------------------------------------------------------------------------------
    --  FindLicAndAppAccHistory() -- PUBLIC
    --  Used by Outrider to Search for Licenses and Application (under label License)
    --  Procedure limits based off of dynamic detail IncludeInAccHistorySearch on Application.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE findlicandappacchistory(
        a_externalfilenum            VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);


    PROCEDURE findlicense(a_externalfilenum            VARCHAR2,
                          a_licenseenames              VARCHAR2,
                          a_dup_premaddressline1       VARCHAR2,
                          a_dup_premaddressuscity      VARCHAR2,
                          a_dup_premzipcode            VARCHAR2,
                          a_dup_dbas                   VARCHAR2,
                          a_createddate                DATE,
                          a_createddateupper           DATE,
                          a_status                     VARCHAR2,
                          a_objects         OUT NOCOPY api.udt_objectlist);

    /**************************************************************************************************
     * FindLicenseAndApplication() -- PUBLIC
     *   Used by Outrider to Search for Licenses and Application (under label License)
     *   User needs to select Status Description, but SearchByJob procedure only takes StatusName.
     * Updated 10/23/2015 by Ryan Lutz for performance
     * Updated address line 2 by Pawan on 3/23/2028
     **************************************************************************************************/
    PROCEDURE findlicenseandapplication(
        a_externalfilenum            VARCHAR2,
        a_regnumber                  VARCHAR2,
        a_licenseenames              VARCHAR2,
        a_premaddressline1           VARCHAR2,
        a_premaddressline2           VARCHAR2,
        a_premuscity                 VARCHAR2,
        a_premzipcode                VARCHAR2,
        a_dup_dbas                   VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_status                     VARCHAR2,
        a_override                   VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    /**************************************************************************************************
     * FindLicenseType() -- PUBLIC
     *   Used by Outrider to Search for License Types
     * Updated 10/23/2015 by Ryan Lutz for performance
     **************************************************************************************************/
    PROCEDURE findlicensetype(
        a_dup_licensetypecode        VARCHAR2,
        a_dup_licensetypename        VARCHAR2,
        a_dup_licenseexternalfilenum VARCHAR2,
        a_dup_licenseenames          VARCHAR2,
        a_dup_licenseaddressline1    VARCHAR2,
        a_dup_licenseaddressline2    VARCHAR2,
        a_dup_licenseuscity          VARCHAR2,
        a_dup_licensezipcode         VARCHAR2,
        a_dup_licensedbas            VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_expirationdate             DATE,
        a_expirationdateupper        DATE,
        a_status                     VARCHAR2,
        a_override                   VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findmanagepriorityapplication(
        a_managepriorityappsnumber   VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_status                     VARCHAR2,
        a_applicationnumber          VARCHAR2,
        a_applicantnames             VARCHAR2,
        a_officecodeandname          VARCHAR2,
        a_countycodeandname          VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);


    ---------------------------------------------------------------------------------------------------
    --  FindMasterLicenseType() -- PUBLIC
    --  Used by Outrider on the Application when establishing a Branch License Type
    --  Searches for a License with a Master License Type to "sponsor" the Branch.
    ---------------------------------------------------------------------------------------------------
    PROCEDURE findmasterlicensetype(
        a_licenseexternalfilenum     VARCHAR2,
        a_licenseenames              VARCHAR2,
        a_licenseaddressline1        VARCHAR2,
        a_licenseuscity              VARCHAR2,
        a_licensezipcode             VARCHAR2,
        a_licensedbas                VARCHAR2,
        a_fromprimarylicensetype     NUMBER,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findmasterprimarylicensetype(
        a_licenseexternalfilenum     VARCHAR2,
        a_licenseenames              VARCHAR2,
        a_licenseaddressline1        VARCHAR2,
        a_licenseuscity              VARCHAR2,
        a_licensezipcode             VARCHAR2,
        a_licensedbas                VARCHAR2,
        a_fromprimarylicensetype     NUMBER,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findmanualfee(a_licensetypecode            VARCHAR2,
                            a_effectivedate              DATE,
                            a_effectivedateupper         DATE,
                            a_description                VARCHAR2,
                            a_searchforhistoricalrecords VARCHAR2,
                            a_excludeobjectids           VARCHAR2,
                            a_processid                  udt_id,
                            a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findmiscellaneousfee(
        a_externalfilenum            VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_status                     VARCHAR2,
        a_paidfor                    VARCHAR2,
        a_amount                     NUMBER,
        a_receiptingoffice           VARCHAR2,
        a_receiptnumber              VARCHAR2,
        a_feedescription             VARCHAR2,
        a_receiptingcompletedby      VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    /**************************************************************************************************
     * FindOneDayLicense() -- PUBLIC
     *   Search for One Day License Jobs
     * Updated 10/23/2015 by Ryan Lutz for performance
     **************************************************************************************************/
    PROCEDURE findonedaylicense(
        a_externalfilenum            VARCHAR2,
        a_organizationname           VARCHAR2,
        a_eventlocaddressline1       VARCHAR2,
        a_eventlocaddressline2       VARCHAR2,
        a_eventlocuscity             VARCHAR2,
        a_eventloczipcode            VARCHAR2,
        a_eventyear                  NUMBER,
        a_representativename         VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_status                     VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findpayment(a_jobid            NUMBER,
                          a_jobnumber        VARCHAR2,
                          a_excludeobjectids VARCHAR2,
                          a_objectlist   OUT api.udt_objectlist);

    PROCEDURE findpaymenttransactions(a_licensenumber    VARCHAR2,
                                      a_licensetypecode  VARCHAR2,
                                      a_objectlist   OUT api.udt_objectlist);

    PROCEDURE findpaymenttransunearned(a_licensenumber    VARCHAR2,
                                       a_licensetypecode  VARCHAR2,
                                       a_objectlist   OUT api.udt_objectlist);

    /**************************************************************************************************
     * FindPerson() -- PUBLIC
     *   Search for Person Objects
     * Updated 10/23/2015 by Ryan Lutz for performance
     * Change a_socialsecuritynumber back to VARCHAR2, NUMERIC truncates leading zero of 4 digit SSN
     **************************************************************************************************/
    PROCEDURE findperson(a_name                       VARCHAR2,
                         a_birthdate                  DATE,
                         a_addressline2               VARCHAR2,   -- added by sri
                         a_socialsecuritynumber       VARCHAR2,          -- WO 15584 Original declared as NUMERIC
                         a_addressline1               VARCHAR2,
                        
                         a_uscity                     VARCHAR2,
                         a_usstate                    VARCHAR2,
                         a_zipcode                    VARCHAR2,
                         a_keywords                   VARCHAR2,
                         a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
                         a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findp12(a_companyname                VARCHAR2,
                      a_firstname                  VARCHAR2,
                      a_lastname                   VARCHAR2,
                      a_addressline1               VARCHAR2,
                      a_uscity                     VARCHAR2,
                      a_usstate                    VARCHAR2,
                      a_zipcode                    NUMBER,
                      a_licensenumber              VARCHAR2,
                      a_p12status                  CHAR,
                      a_objects         OUT NOCOPY api.udt_objectlist);

    -------------------------------------------
    PROCEDURE findprocesses(
        a_jobid                      udt_id,
        a_startdate                  DATE := ADD_MONTHS(SYSDATE, -12),
        a_enddate                    DATE := SYSDATE,
        a_includeincomplete          VARCHAR2 := 'Y',
        a_objects         OUT NOCOPY api.udt_objectlist);

    -------------------------------------------
    PROCEDURE findprotestant(a_jobid                      NUMBER,
                             a_lastname                   VARCHAR2,
                             a_firstname                  VARCHAR2,
                             a_addressline1               VARCHAR2,
                             a_city                       VARCHAR2,
                             a_state                      VARCHAR2,
                             a_zipcode                    VARCHAR2,
                             a_statusreason               VARCHAR2,
                             a_notificationdatefrom       DATE,
                             a_notificationdateto         DATE,
                             a_username                   VARCHAR2,
                             a_objects         OUT NOCOPY api.udt_objectlist);

    /*---------------------------------------------------------------------------
     * FindAllProtestants() -- Mike Lott
     * Added to allow searching for Protestants without a job constraint.
     *-------------------------------------------------------------------------*/
    PROCEDURE findallprotestants(
        a_lastname                   VARCHAR2,
        a_firstname                  VARCHAR2,
        a_addressline1               VARCHAR2,
        a_city                       VARCHAR2,
        a_state                      VARCHAR2,
        a_zipcode                    VARCHAR2,
        a_overridesearchlimit        VARCHAR2 DEFAULT 'N',
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findrefundpayment(
        a_dup_licensenumber          VARCHAR2,
        a_paymentdate                DATE,
        a_paymentdateupper           DATE,
        a_dup_receiptnumber          VARCHAR2,
        a_batchid                    VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findtransferablelicense(
        a_externalfilenum            VARCHAR2,
        a_licenseenames              VARCHAR2,
        a_dup_premaddressline1       VARCHAR2,
        a_dup_premaddressuscity      VARCHAR2,
        a_dup_premzipcode            VARCHAR2,
        a_dup_dbas                   VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE findtransmittal(
        a_status                     VARCHAR2,
        a_createddate                DATE,
        a_createddateupper           DATE,
        a_cashiereddate              DATE,
        a_cashiereddateupper         DATE,
        a_externalfilenum            VARCHAR2,
        a_districtoffice             VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);



    PROCEDURE findusersbyoffice(
        a_user                       VARCHAR2,
        a_officename                 VARCHAR2,
        a_relatedobjectids   OUT NOCOPY api.udt_objectlist);


    /*-------------------------------------------------------------------------------
     * Procedure FindUserProcesses()
     *   Purpose: This procedure will return a list of incompleted processes assigned to
     *            a current login user for the purpose of filling a To-Do-List. You have
     *            the option of either displaying current processes(i.e. the scheduledstartdate
     *            is null or it is less than the sysdate) or all processes.
     *-----------------------------------------------------------------------------*/
    PROCEDURE finduserprocesses(
        a_user                       VARCHAR2,
        a_processtype                VARCHAR2,
        a_investigations             VARCHAR2,
        a_jobexternalfilenum         VARCHAR2,
        a_datecompletedfrom          DATE,
        a_datecompletedto            DATE,
        a_relatedobjectids   OUT NOCOPY api.udt_objectlist);

    PROCEDURE licensetypejobsltsearch(a_licensetypejobid NUMBER,
                                      a_excludeobjectids VARCHAR2,
                                      a_objectlist   OUT api.udt_objectlist);

    PROCEDURE pltobjectsecondaryltsearch(
        a_primaryltobjectid NUMBER,
        a_objectlist   OUT api.udt_objectlist);


    /**************************************************************************************************
     * PaymentSearch() -- PUBLIC
     *   This procedure will find Payments for the given criteria
     * Updated 10/23/2015 by Ryan Lutz for performance
     **************************************************************************************************/
    PROCEDURE paymentsearch(a_office                     NUMBER,
                            a_paymentdate                DATE,
                            a_paymentdateupper           DATE,
                            a_payeereference             VARCHAR2,
                            a_paymentamount              NUMBER,
                            a_payeename                  VARCHAR2,
                            a_sequencenum                VARCHAR2,
                            a_paymentmethod              NUMBER,
                            a_transmittalid              VARCHAR2,
                            a_licensenumber              VARCHAR2,
                            a_receiptnumber              VARCHAR2,
                            a_depositnumber              NUMBER,
                            a_override                   VARCHAR2,
                            a_objects         OUT NOCOPY api.udt_objectlist);

    ---------------------------------------------------------------
    -- PaymentJobSearch()
    -- This procedure will find Payments for the given criteria
    -- This will limit out the Refunded, Negative, and Dishonored payments.
    ---------------------------------------------------------------

    PROCEDURE paymentjobsearch(
        a_office                     VARCHAR2,
        a_paymentdate                DATE,
        a_paymentdateupper           DATE,
        a_payeereference             VARCHAR2,
        a_paymentamount              NUMBER,
        a_payeename                  VARCHAR2,
        a_sequencenum                VARCHAR2,
        a_paymentmethod              VARCHAR2,
        a_transmittalid              VARCHAR2,
        a_licensenumber              VARCHAR2,
        a_receiptnumber              VARCHAR2,
        a_depositnumber              NUMBER,
        a_currentobjectids           VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    PROCEDURE finddishonoredpayment(
        a_dup_licensenumber          VARCHAR2,
        a_paymentdate                DATE,
        a_paymentdateupper           DATE,
        a_dup_receiptnumber          VARCHAR2,
        a_batchid                    VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    /**************************************************************************************************
     * FindCatererEventAuths() -- PUBLIC
     *   This procedure finds all the Caterer/Event Permit Auth Processes based on the specified criteria
     * Updated 10/23/2015 by Ryan Lutz for performance
     **************************************************************************************************/
    PROCEDURE findcaterereventauths(
        a_licensenumber              VARCHAR2,
        a_licenseenames              VARCHAR2,
        a_lspid                      VARCHAR2,
        a_dateofeventfrom            DATE,
        a_dateofeventto              DATE,
        a_eventlocationaddressline1  VARCHAR2,        
        a_eventlocationaddressline2  VARCHAR2,
        a_eventlocationcity          VARCHAR2,
        a_eventlocationzip           VARCHAR2,
        a_conditionalonly            VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

 /**************************************************************************************************
     * FindInspection() -- PUBLIC
     *   This procedure finds all the Impact Inspection based on the specified criteria
     * Created 01/28/2019 By Pawanjit Kaur WO 13953 Added Search Functionality For Impact Inspections
 **************************************************************************************************/         
     PROCEDURE findinspection(
        a_office                     NUMBER,
        a_inspectionnumber           VARCHAR2,
        a_abcreportnumber            VARCHAR2,
        a_inspectiontype             VARCHAR2,
        a_agent                      VARCHAR2,
        a_licensenumber              VARCHAR2,
        a_addressline1               VARCHAR2,
        a_city                       VARCHAR2,
        a_state                      VARCHAR2,
        a_zipcode                    VARCHAR2,
        a_status                     VARCHAR2,
        a_createdstartdate           DATE,
        a_createdenddate             DATE,
        a_completedstartdate         DATE,
        a_completedenddate           DATE,
        a_objects         OUT NOCOPY api.udt_objectlist);

    ---------------------------------------------------------
    --  StaffUiFindPaymentTransUnearn() -- PUBLIC
    --  Wrapper procedure for FindPaymentTransactions.
    --  Allows results of FindPaymentTransactions to be used in the StaffUI system.
    --  Created 12/09/2021 By Samuel Fehr.
    ---------------------------------------------------------
    PROCEDURE staffuifindpaymenttransunearn(
        a_rownum                     number,
        a_licensenumber              VARCHAR2,
        a_licensetypecode            VARCHAR2);
END pkg_abcsearch;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_ABCSEARCH TO POSSEEXTENSIONS;
