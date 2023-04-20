CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_tlreports
AS
    -- **************************************************************************
    -- File:        PKG_TLREPORTS.PKS
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

    -- Author  : PAULO
    -- Created : 7/21/2013

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;


    /*-------------------------------------------------------------------------
     * GrantMonthlySummaryReport() - Public
     * This procedure inserts rows into sitespecific.GrantMonthlySummary_gt
     * for the TRACE/LEAD Monthly Sumary Report
     *------------------------------------------------------------------------*/

    PROCEDURE grantmonthlysummaryreport(a_objectid udt_id);

    /*-------------------------------------------------------------------------
    * ABCMonthlySummaryReport() - Public
    * This procedure inserts rows into sitespecific.ABCMonthlySummary_gt
    * for the TRACE/LEAD Monthly Sumary Report for All ABC operations
    *------------------------------------------------------------------------*/

    PROCEDURE abcmonthlysummaryreport(a_objectid udt_id);

    /*-------------------------------------------------------------------------
     * GAPMonthlySummaryReport() - Public
     * This procedure inserts rows into sitespecific.ABCMonthlySummary_gt
     * for the TRACE/LEAD GAP Agency Monthly Sumary Report
     *------------------------------------------------------------------------*/

    PROCEDURE gapmonthlysummaryreport(a_objectid udt_id);

    /*-------------------------------------------------------------------------
      * MiniMonthlySummaryReport() - Public
      * This procedure inserts rows into sitespecific.ABCMonthlySummary_gt
      * for the TRACE/LEAD Mini-Grant Monthly Sumary Report
      *------------------------------------------------------------------------*/
    PROCEDURE minimonthlysummaryreport(a_objectid udt_id);

    /*-------------------------------------------------------------------------
      * OtherMonthlySummaryReport() - Public
      * This procedure inserts rows into sitespecific.ABCMonthlySummary_gt
      * for the TRACE/LEAD Other Monthly Sumary Report
      *------------------------------------------------------------------------*/

    PROCEDURE othermonthlysummaryreport(a_objectid udt_id);
END pkg_tlreports;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_TLREPORTS TO POSSEEXTENSIONS;
