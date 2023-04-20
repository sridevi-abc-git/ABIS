CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_tlutilities
IS
    -- **************************************************************************
    -- File:        PKG_TLUTILITIES.PKS
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /******************************************************************
    checklicensenumber is run in the TRACe/LEAD system when supplied a license number
    it checks wheter or not it is a valid license in ABIS
    ******************************************************************/
    PROCEDURE checklicensenumber(a_objectid      udt_id,
                                 a_asofdate      DATE,
                                 a_licensenumber VARCHAR2);

    /******************************************************************
    GenerateLEADCertificate is run on the LEAD class object when the email LEAD
    certificate button is pressed, If the Student passed the LEAD class create a
    process on the process server that will be used to Print the LEAD certificate
    ******************************************************************/
    PROCEDURE generateleadcertificates(a_objectid udt_id, a_asofdate DATE);

    /******************************************************************
    RelateLEADStudentsToProcess is run on the p_tl_PrintLeadCertificate process
    on contrctor to relate the newly created process to the student Registration Object
    ******************************************************************/

    PROCEDURE relateleadstudentstoprocess(a_objectid udt_id, a_asofdate DATE);

    /******************************************************************
    SendLEADClassEmail is run on the TRACE class object when the email lead
    certificate button is pressed
    ******************************************************************/
    PROCEDURE sendleadclassemail(a_objectid udt_id, a_asofdate DATE);

    /******************************************************************
    SendLEADCancelledEmail is run on the TRACE class object when the email lead
    certificate button is pressed
    ******************************************************************/
    PROCEDURE sendleadcancelledemail(a_objectid udt_id, a_asofdate DATE);

    /*****************************************************************
    SendTRACECaseEmail is run on the TRACE Complaint object when the complaint
    is submitted.
    ******************************************************************/
    PROCEDURE sendtracecaseemail(a_objectid udt_id, a_asofdate DATE);

    PROCEDURE checkstudentemailaddr(a_objectid      udt_id,
                                    a_asofdate      DATE,
                                    a_emailaddr     VARCHAR2,
                                    a_trainingdate  DATE);

    --procedure ClassList(a_ObjectId     IN  udt_Id,
    --                    a_ASOfDate     IN  date,
    --                    a_TrainingDate IN  date,
    --                    a_ClassList    OUT SYS_REFCURSOR);

    PROCEDURE unregisterstudent(a_objectid     IN     udt_id,
                                a_asofdate     IN     DATE,
                                a_emailaddress IN     VARCHAR2,
                                a_confirmation IN     NUMBER,
                                a_msg             OUT VARCHAR2);
END pkg_tlutilities;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_TLUTILITIES TO POSSEEXTENSIONS;
