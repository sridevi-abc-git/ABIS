CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_COPY_LICENSE"
AS
    -- **************************************************************************
    -- File:        PKG_COPY_LICENSE.pks
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
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    -- Public type declarations
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    ----------------------------------------------------------------------------------------------------
    -- * CopyLicDetailsToApp() -- PUBLIC
    -- Copy details and relationsihps from license to an application to transfer or change a license.
    -- Depending on application type, this can include:
    -- Licensees, License Types, Hold, Mail Address, DBA, Base File Office
    -- Input is the application objId
    -- Runs on Post Verify of Application Job.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE copylicdetailstoapp(a_appobjectid udt_id, a_asofdate DATE);

    ----------------------------------------------------------------------------------------------------
    -- * CopyPriorityLicDetailsToApp() -- PUBLIC
    -- This is used on the Priority Application.
    -- Copy details and relationsihps from license to an transfer application.
    -- Depending on application type, this can include:
    -- Licensees, License Types, Hold, Mail Address, DBA, Base File Office
    -- Input is the application objId
    -- Runs on Post Verify of Application Job.
    -- This is used on the Priority Application.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE copyprioritylicdetailstoapp(a_appobjectid   udt_id,
                                          a_asofdate      DATE);
END pkg_copy_license;

/


GRANT EXECUTE ON SITESPECIFIC.PKG_COPY_LICENSE TO POSSEEXTENSIONS;
