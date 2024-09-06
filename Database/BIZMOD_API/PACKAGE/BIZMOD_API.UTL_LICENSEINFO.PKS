CREATE OR REPLACE PACKAGE BIZMOD_API.utl_licenseinfo
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.UTL_LICENSEINFO.PKS
    -- Author:      Timothy J. Lord
    --
    -- Purpose:
    --
    -- History:
    -------------------------------------------------------------------------------
    --   VER:      Date           Ticket     Comment
    --   2.1    07/25/2023  TJL  BIZ-12102    Added procedure get_awfreninfo
    --   4.0    10/18/2023  TJL  BIZ-12887    Added new function to allow ABIS to send information to LSP
    --                                          HTTPS endpoints. Function CALLLSP
    --   4.1    12/07/2023  TJL  BIZ-12802    Removed old CALLLSP function
    --   6.0    03/26/2024  TJL  BIZ-14833    Added new functions (get_application and checkpayment
    --   6.1    03/28/2024  TJL  BIZ-14833    Remove functions (awfrequired and get_awfreninfo)
    --   7.0    05/09/2024  TJL  BIZ-15444    Added global types used for license application
    --                                          function and process job
    --   7.1    05/24/2024  TJL  BIZ-15485    Add email function to use new configuration table
    --   8.0    07/01/2024  TJL  BIZ-15444    Added procedure CREATEJOB
    --   8.0.1  07/08/2024  TJL  BIZ-15800    Updated gc_apprec_t record
    --   9.0.1  07/22/2024  TJL  BIZ-15800    Updated gc_* records
    --  10.0.1  08/07/2024  TJL  BIZ-16000    Added new CALLLSP Function
    --  10.1.0  08/29/2024  TJL  BIZ-16000    Added columns to gc_apprec
    -- ****************************************************************************

    TYPE gc_apprec_t IS RECORD(applicationtype VARCHAR2(50),
                               transferchangetype VARCHAR2(100),
                               transferchangelicensenumber VARCHAR2(50),
                               multiplestockmembershiptrans VARCHAR2(1),    
                               lspapplicationid VARCHAR2(40),
                               underconstruction VARCHAR2(3),
                               prioritydrawapplication VARCHAR2(1),
                               prioritydrawcounty VARCHAR2(4000),
                               dba VARCHAR2(4000),
                               felony VARCHAR2(3),
                               violation VARCHAR2(3),
                               licensepurchaseprice NUMBER,                               
                               primarylicensetypes VARCHAR2(4000),
                               premiseaddress VARCHAR2(4000),
                               mailingaddress VARCHAR2(4000),
                               attorney CLOB,
                               escrow CLOB,
                               legal_entities CLOB);

    TYPE gc_addr_t IS RECORD(addresslocation VARCHAR2(4000), 
                             addressline1 VARCHAR2(4000),
                             addressline2 VARCHAR2(4000),
                             usacity VARCHAR2(4000),
                             usastate VARCHAR2(4000),
                             zipcode VARCHAR2(4000),
                             phonenumber VARCHAR2(4000),
                             faxnumber VARCHAR2(4000),
                             internationalphonenumber VARCHAR2(4000),
                             censustract VARCHAR2(4000),
                             censustractsource VARCHAR2(4000),
                             geocodeaddressline1 VARCHAR2(4000),
                             outsidecitylimits VARCHAR2(3),
                             highcrime VARCHAR2(3),
                             cardroomcasino VARCHAR2(3),
                             noevent VARCHAR2(3),
                             eligiblefortransfer VARCHAR2(3));

--    TYPE gc_entity_t IS RECORD(TYPE VARCHAR2(4000),
--                               ownertype VARCHAR2(4000),
--                               percentage NUMBER,
--                               firstname VARCHAR2(4000),
--                               middlename VARCHAR2(4000),
--                               lastname VARCHAR2(4000),
--                               suffix VARCHAR2(20),
--                               aliasnames VARCHAR2(4000),
--                               socialsecuritynumber VARCHAR2(4),
--                               driverslicensenumber VARCHAR2(4000),
--                               driverslicensestate VARCHAR2(4000),
--                               passportnumber VARCHAR2(4000),
--                               gender VARCHAR2(4000),
--                               birthdate DATE,
--                               birthcity VARCHAR2(4000),
--                               birthstate VARCHAR2(4000),
--                               birthcountry VARCHAR2(4000),
--                               maritalstatus VARCHAR2(4000),
--                               federalemployeridentificationn VARCHAR2(4000),
--                               address CLOB,
--                               legal_entities CLOB);

    TYPE gc_person_t IS RECORD(firstname VARCHAR2(4000),
                               middlename VARCHAR2(4000),
                               lastname VARCHAR2(4000),
                               suffix VARCHAR2(20),
                               aliasnames VARCHAR2(4000),
                               socialsecuritynumber VARCHAR2(4),
                               driverslicensenumber VARCHAR2(4000),
                               driverslicensestate VARCHAR2(4000),
                               passportnumber VARCHAR2(4000),
                               gender VARCHAR2(4000),
                               birthdate DATE,
                               birthcity VARCHAR2(4000),
                               birthstate VARCHAR2(4000),
                               birthcountry VARCHAR2(4000),
                               maritalstatus VARCHAR2(4000),
                               address CLOB);

    TYPE gc_company_t IS RECORD(companyname VARCHAR2(4000),
                                companystructure VARCHAR2(4000), 
                                dateofincorporation  DATE,
                                stateofincorporation  VARCHAR2(4000),
                                casecretaryofstatenumber  VARCHAR2(4000),
                                federalemployeridentificationn  VARCHAR2(4000),
                                address CLOB);

    FUNCTION calllsp(a_urlinfo     IN     VARCHAR2,
                     a_method       IN     VARCHAR2,
                     a_content      IN     CLOB DEFAULT NULL,
                     a_file         IN     BLOB DEFAULT NULL)
        RETURN CLOB;

    FUNCTION statusmatrix(a_status IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE clean(a_json IN OUT json_object_t);

    FUNCTION get_application(a_jobid        IN NUMBER,
                             a_licensetypecode IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION checkpayment(a_licensenumber IN VARCHAR2,
                          a_licensetypecode IN VARCHAR2,
                          a_renewalfeedate IN DATE)
        RETURN VARCHAR2;

    PROCEDURE sendemail(a_process      IN VARCHAR2 DEFAULT 'EMAIL',
                        a_subject      IN VARCHAR2,
                        a_body         IN VARCHAR2,
                        a_file_name    IN VARCHAR2 DEFAULT NULL,
                        a_clob         IN CLOB DEFAULT NULL,
                        a_encoding        VARCHAR2 DEFAULT 'text/plain',
                        a_mimetype        VARCHAR2 DEFAULT 'text/plain');

    PROCEDURE createjob(a_procedure    IN VARCHAR2,
                        a_description  IN VARCHAR2,
                        a_argument1    IN VARCHAR2 DEFAULT '0',
                        a_argument2    IN DATE DEFAULT SYSDATE,
                        a_argument3    IN VARCHAR2 DEFAULT NULL);
END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO LORDT;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO SITESPECIFIC;
