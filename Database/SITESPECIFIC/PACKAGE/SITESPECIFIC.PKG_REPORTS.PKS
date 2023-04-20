CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_REPORTS"
AS
    -- **************************************************************************
    -- File:        PKG_REPORTS.PKS
    -- Author:      ANDREWP
    --
    -- $Rev: 340 $
    -- $Date: 2019-06-30 07:34:09 -0700 (Sun, 30 Jun 2019) $
    -- Last Changed By:  $Author: tlord $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 04/01/2018 AP          Package Created
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    ---------------------------------------------------------------------------
    -- ChooseInvestigatorLR() -- PUBLIC
    -- Used by the ABC-229 Bulk object
    -- Provides a list of Investigators and LR's for the entire system
    ---------------------------------------------------------------------------
    PROCEDURE chooseinvestigatorlr(a_object           udt_id,
                                   a_relationshipdef  udt_id,
                                   a_endpoint         udt_endpoint,
                                   a_searchstring     VARCHAR2,
                                   a_objects      OUT udt_objectlist);

    /***********************************************************************************************
    ** FUNCTION FeeEarnedSummaryMessage
    **
    **
    **
    **
    ***********************************************************************************************/
    FUNCTION feeearnedsummarymessage(a_jobid         udt_id,
                                     a_licensetypecode VARCHAR2,
                                     a_ismaster      VARCHAR2,
                                     a_secondarycount NUMBER,
                                     a_jobtypeid     udt_id)
        RETURN NUMBER;

    -------------------------------------
    --
    -------------------------------------

    PROCEDURE revenuereport(a_startdate DATE, a_enddate DATE);

    ---------------------------
    --
    ----------------------------

    PROCEDURE allocationreport(a_startdate DATE, a_enddate DATE);
    
    PROCEDURE allocationreport2(a_startdate DATE, a_enddate DATE);

    /*--------------------------
    -- DepositReportDetail() PUBLIC
    -- This generates the results for the Deposit Report (Detail)
    ---------------------------*/

    PROCEDURE depositreportdetail(a_startdate DATE, a_enddate DATE);

    /*--------------------------
    -- GreenPinkLicense() PUBLIC
    -- This determines which procedure to run and produce the report
    ---------------------------*/
    PROCEDURE greenpinklicense(a_objectid udt_id);

    /*--------------------------
    -- PrintLicenseBatch() PUBLIC
    -- This procedure loads a GTT with data for the Green and Pink License Reports.
    ---------------------------*/
    PROCEDURE printlicensebatch(a_objectid udt_id);

    /*--------------------------
    -- ManualProduceLicense() PUBLIC
    -- This will load a GTT for the Green and Pink License Report
    ---------------------------*/
    PROCEDURE manualproducelicense(a_objectid udt_id);

    /*--------------------------------------------------------------
    -Owners Report is called from the license report nested data
    -window to return only the amount of rows that can be fully
    -rendered
    ----------------------------------------------------------------*/
    FUNCTION ownerreport(a_jobid udt_id)
        RETURN extension.udst_stringlist;

    /*--------------------------
    -- RenewalListReport() PUBLIC
    -- This will load a GTT for the Renewal List report.
    -- The Finacial section is based on the Accounting History Report
    ---------------------------*/
    PROCEDURE renewallistreport(a_juliandate VARCHAR2);

    /*-------------------------------------------------------------------------
    * AccountingHistoryReport() - Public
    * This procedure inserts rows into sitespecific.accountinghistory_gt
    * for the Accounting history report that is run in Outrider for
    * a License or Application.
    *------------------------------------------------------------------------*/

    PROCEDURE accountinghistoryreport(a_objectid udt_id);

    --*------------------------------------------------------------------------------------------------
    --* GetPayTransForAccHist() -- PUBLIC
    --* This procedure is getting the valid Payment Transactions for the Accounting History Report
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getpaytransforacchist(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist);

    --*------------------------------------------------------------------------------------------------
    --* GetZeroDollarFeesForAccHist() -- PUBLIC
    --* This procedure is getting the Zero Dollar Fees for the Accounting History Report
    --*------------------------------------------------------------------------------------------------

    PROCEDURE getzerodollarfeesforacchist(
        a_objectid         udt_id,
        a_ptcreateddate    DATE,
        a_relatedobjectids OUT api.udt_objectlist);

    PROCEDURE workloadsummaryrevenue(a_year NUMBER);

    PROCEDURE dailyintakevoids(a_startdate DATE, a_enddate DATE);
END pkg_reports;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_REPORTS TO ABCCONV;

GRANT EXECUTE ON SITESPECIFIC.PKG_REPORTS TO ABCREPORTS;

GRANT EXECUTE ON SITESPECIFIC.PKG_REPORTS TO POSSEEXTENSIONS;
