CREATE OR REPLACE PACKAGE ABCLQS.LQS_Alcohol_To_Go
AS
    -- **************************************************************************
    -- File:        LQS_Alcohol_To_Go.PKS
    -- Author:      Ning Wong
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 12/06/2021 NW        	
    -- **************************************************************************
-----------------------------
PROCEDURE ALCOHOL_TO_GO(
-----------------------------
	a_parameters IN XMLTYPE, 
	a_reportdata OUT BLOB, 
	a_message OUT VARCHAR
);

-----------------------------
PROCEDURE GET_LICENSE(
-----------------------------
	a_parameters IN XMLTYPE, 
	a_reportdata OUT BLOB, 
	a_message OUT VARCHAR
);

--------------------------
PROCEDURE UPDATE_LICENSE(
--------------------------
	a_parameters IN XMLTYPE, 
	a_reportdata OUT BLOB, 
	a_message OUT VARCHAR
);

---------------------------
FUNCTION GET_LICENSE_TYPES (
---------------------------
 p_licenseNumber VARCHAR2 
) 
RETURN XMLTYPE;

END;
/
