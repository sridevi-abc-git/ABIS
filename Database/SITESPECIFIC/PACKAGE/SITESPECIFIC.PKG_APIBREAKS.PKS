CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_apibreaks
IS
    -- **************************************************************************
    -- File:        PKG_APIBREAKS.pks
    -- Author:      JOSHUAC
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Purpose : Documents where custom code has broken
    --           the Documented POSSE API.
    --
    --    1.  pkg_SysSchedule is used to schedule a process on the process
    --        server.
    --
    --    2.  PRTG sensor to monitor for failed corral syncs.
    --        admin.backgroundprocesses.
    --
    --    3.  Automatic trigger on toolbox.deferredprocedures to update the
    --        user to CONV. Deferred procedures do not work with instance security
    --
    --    4.  When running upgrades run the following two grants
    --        grant all on toolbox.deferredprocedures to extension;
    --        grant all on toolbox.deferredprocedures to sitespecific;
    --    5.  Exposing toolbox.MaintainDuplicateDetails to be used from package code
    --        currently being used in the legal entity package (pkg_LegalEntity.AddOfficerStockolderInfo).
    --        This is used for resolution of a timing issue.
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    PROCEDURE maintainduplicatedetails(a_objectid NUMBER);
END pkg_apibreaks;
/
