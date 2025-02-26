CREATE OR REPLACE PACKAGE ABCLQS.LQS_DETAIL AS
-- ****************************************************************************
-- File:        LQS_DETAIL.pks     
-- Author:      Ning Wong
--
-- $Rev: 3590 $  
-- $Date: 2017-09-15 17:10:32 -0700 (Fri, 15 Sep 2017) $
-- Last Changed By:  $Author: nwong $
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 09/01/2017 TJL   11670   Header for version tracking 
-- 09/15/2017 NW	          Holds - Changed parameter
-- 09/29/2017 NW            GET_LICENSE_INFO to GET_LICENSEE_INFO 
-- 02/25/2025 PK            Added Notification for LA fires
-- ****************************************************************************
    PROCEDURE LQS_LICENSE
    ( p_parameters  IN XMLTYPE 
    , p_data        OUT BLOB
    , p_message     OUT VARCHAR );

    FUNCTION GET_LICENSEE_INFO
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
   ( p_LicenseNum MART.APPLICATION.EXTERNALFILENUM%TYPE )    
    RETURN XMLTYPE;

    FUNCTION GET_ESCROW
    ( p_JobId INTEGER)
    RETURN XMLTYPE;
    
     FUNCTION GET_NOTIFICATIONS
       ( p_JobId INTEGER)
    RETURN XMLTYPE;

END LQS_DETAIL;
/
