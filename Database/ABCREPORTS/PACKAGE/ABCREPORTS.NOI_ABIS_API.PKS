CREATE OR REPLACE PACKAGE ABCREPORTS.NOI_ABIS_API
AS
    -- **************************************************************************
    -- File:        NOI_ABIS_API.PKS
    -- Author:      Ning Wong
    --
    -- Description: Scheduled jobs to update ABCREPORTS and ABIS
    --
    --  LOAD_LQS_LICENSE - Load ABCLQS.LICENSE table from ABIS
    --  UPDATE_ABIS_NOI  - Updates ABIS NOI fields from ABCREPORTS.ALCOHOL_NOI_LOG
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 12/06/2021 NW        	Initialization
    -- **************************************************************************
-----------------------------
PROCEDURE LOAD_LQS_LICENSE;
-----------------------------


-----------------------------
PROCEDURE UPDATE_ABIS_NOI;
-----------------------------

END;
/
