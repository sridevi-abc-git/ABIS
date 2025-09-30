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
    --  11.0.0  09/09/2024  TJL  BIZ-16077    Added columns country, addressline3
    --                                          to gc_addr_t
    --  12.0.0  10/08/2024  TJL  BIZ-16424    Added get_address and get_legalentity functions
    --  12.1.0  10/23/2024  TJL  BIZ-16424    Added istemporarymailingaddress to gc_apprec_t
    --  12.2.0  12/03/2024  TJL  BIZ-16842    Added fields to gc_person_t
    --  12.3.0  01/10/2025  TJL               Removed priority info from gc_apprec_t
    --  12.4.0  01/28/2025  TJL  BIZ-17289    Added recursive call to CALLLSP to get JWT token
    --  12.5.0  02/03/2025  TJL  BIZ-17356    Added lsplogin function
    --  12.5.2  02/07/2025  TJL  BIZ-17356    Code cleanup
    --  13.0.0  05/02/2025  TJL  BIZ-18056    Change prototype for calllsp.
    --  15.0.0  09/10/2025  BN   BIZ-19069    Added method to generate hashvalue for an application.
    --  16.0.0  09/30/2025  TJL  BIZ-19339    Add retry to call LSP on timeout
    -- ****************************************************************************

    TYPE gc_apprec_t IS RECORD(applicationtype VARCHAR2(50),
                               transferchangetype VARCHAR2(100),
                               transferchangelicensenumber VARCHAR2(50),
                               multiplestockmembershiptrans VARCHAR2(1),
                               lspapplicationid VARCHAR2(40),
                               underconstruction VARCHAR2(3),
                               dba VARCHAR2(4000),
                               felony VARCHAR2(3),
                               violation VARCHAR2(3),
                               licensepurchaseprice NUMBER,
                               primarylicensetypes VARCHAR2(4000),
                               premiseaddress VARCHAR2(4000),
                               mailingaddress VARCHAR2(4000),
                               istemporarymailingaddress VARCHAR2(3),
                               attorney CLOB,
                               escrow CLOB,
                               legal_entities CLOB);

    TYPE gc_addr_t IS RECORD(addresslocation VARCHAR2(4000),
                             addressline1 VARCHAR2(4000),
                             addressline2 VARCHAR2(4000),
                             addressline3 VARCHAR2(4000),
                             usacity VARCHAR2(4000),
                             usastate VARCHAR2(4000),
                             zipcode VARCHAR2(4000),
                             country VARCHAR2(4000),
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

    TYPE gc_company_t IS RECORD(companyname VARCHAR2(4000),
                                companystructure VARCHAR2(4000),
                                dateofincorporation  DATE,
                                stateofincorporation  VARCHAR2(4000),
                                casecretaryofstatenumber  VARCHAR2(4000),
                                federalemployeridentificationn  VARCHAR2(4000),
                                address CLOB);

    FUNCTION lsplogin
        RETURN json_object_t;

    FUNCTION calllsp(a_urlinfo      IN VARCHAR2,
                     a_method       IN VARCHAR2,
                     a_content      IN json_element_t DEFAULT json_object_t(), -- 05/02/2025  TJL  BIZ-18056
                     a_file         IN BLOB DEFAULT NULL,
                     a_token        IN VARCHAR2 DEFAULT NULL,
                     a_retry        IN BOOLEAN DEFAULT FALSE)
        RETURN json_object_t;

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
                        a_argument3    IN VARCHAR2 DEFAULT NULL,
                        a_argument4    IN VARCHAR2 DEFAULT NULL);
    FUNCTION getHashvalueForApplication(a_jobid IN NUMBER)
        RETURN NUMBER;

END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BHAVYAN;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO LORDT;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO SITESPECIFIC;
