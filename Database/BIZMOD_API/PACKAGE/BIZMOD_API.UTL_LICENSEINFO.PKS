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
    -- ****************************************************************************

    TYPE gc_apprec_t IS RECORD(appl_type VARCHAR2(50),
                               lsp_application_id VARCHAR2(40),
                               primary_license_types VARCHAR2(4000),
                               premise_address VARCHAR2(4000),
                               mailing_address VARCHAR2(4000),
                               legal_entities CLOB);

    TYPE gc_addr_t IS RECORD(address_1 VARCHAR2(4000),
                             address_2 VARCHAR2(4000),
                             city VARCHAR2(4000),
                             state VARCHAR2(4000),
                             zip VARCHAR2(4000));
                             
    TYPE gc_entity_t IS RECORD(TYPE VARCHAR2(4000),
                               first_name VARCHAR2(4000),
                               last_name VARCHAR2(4000),
                               owner_type VARCHAR2(4000),
                               percentage number(6,2),
                               address  CLOB,
                               legal_entities CLOB);

    FUNCTION calllsp(a_process      in varchar,
                     a_parameternames IN OUT json_object_t,
                     a_replacementvalues IN json_object_t,
                     a_content      IN CLOB DEFAULT NULL,
                     a_file         IN BLOB DEFAULT NULL)
        RETURN CLOB;

    FUNCTION statusmatrix(a_status IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE clean(a_json IN OUT json_object_t);

    FUNCTION get_application(a_jobid IN NUMBER, a_licensetypecode IN VARCHAR2)
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
