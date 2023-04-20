CREATE OR REPLACE PACKAGE SITESPECIFIC.PKG_TLREMINDER AS
-- ****************************************************************************
-- File:        PKG_TLREMINDER.pks  
-- Author:      Timothy J. Lord
--
-- $Rev: 2510 $  
-- $Date: 2016-03-20 15:50:16 -0700 (Sun, 20 Mar 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description: PKG_TLEMAI package specifications   
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date            Comment
-- 01/03/2014 TJL  Initial File created 
-- 03/17/2016 TJL  9242  Changed SYSDATE +2 to +5  
-- ****************************************************************************

    PROCEDURE SendReminders(p_reminderDate IN DATE DEFAULT SYSDATE + 5);
    

END PKG_TLREMINDER;
/
