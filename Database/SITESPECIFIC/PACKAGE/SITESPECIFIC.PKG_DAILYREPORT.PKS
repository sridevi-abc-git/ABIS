CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_dailyreport
AS
    -- **************************************************************************
    -- File:        PKG_DAILYREPORT.pks
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


    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*---------------------------------------------------------------------------
     * FindFiscalYear() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE findabc22report(
        a_investigationdate          DATE,
        a_investigationdateto        DATE,
        a_dup_lrinvestigator         VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist);

    /*---------------------------------------------------------------------------
    * GetInvestUserLogForInvestFieldVisit() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE getinvuserlogforabc22report(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist);

    /*---------------------------------------------------------------------------
    * GetUserLogsforInvesFieldVisit() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE getlruserlogsforabc22report(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist);

    /*---------------------------------------------------------------------------
    * RelateUserToInvestFieldVisit() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE relateusertoabc22report(a_objectid udt_id, a_asofdate DATE);
END pkg_dailyreport;
/
