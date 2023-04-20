CREATE OR REPLACE PACKAGE ABC.LQS_DETAIL AS
/******************************************************************************
   NAME:       LQS
   PURPOSE:

   REVISIONS:
   Ver        Date        Author          Description
   ---------  ----------  --------------  ------------------------------------
   1.1        8/18/2017   nwong           1. Move license detail procs and funcs into this package 
******************************************************************************/
    PROCEDURE LQS_LICENSE
    ( p_parameters  IN XMLTYPE 
    , p_data        OUT BLOB
    , p_message     OUT VARCHAR );

    FUNCTION GET_LICENSE_INFO
    ( p_JobId INTEGER )
    RETURN XMLTYPE;  

    FUNCTION GET_LICENSE_TYPES
    ( p_JobId INTEGER ) 
    RETURN XMLTYPE;


    FUNCTION GET_TRANSFER_FROM
    ( p_LT_Object_id INTEGER )
    RETURN XMLTYPE; 
    
    FUNCTION GET_TRANSFER_TO
    ( p_LT_Object_id INTEGER )
    RETURN XMLTYPE;

    FUNCTION GET_CONDITIONS
    ( p_LT_JobId INTEGER )
    RETURN XMLTYPE;

    FUNCTION GET_OPERATING_CONDITIONS
    ( p_JobId INTEGER )
    RETURN XMLTYPE;
    
    FUNCTION GET_CURRENT_DISCIPLANARY_ACT
    ( p_JobId INTEGER )
    RETURN XMLTYPE;

    FUNCTION GET_DISCIPLANARY_HISTORY
    ( p_JobId INTEGER )
    RETURN XMLTYPE;

    FUNCTION GET_HOLDS
    ( p_JobId INTEGER )
    RETURN XMLTYPE;

    FUNCTION GET_ESCROW
    ( p_JobId INTEGER)
    RETURN XMLTYPE;

END LQS_DETAIL;
/
