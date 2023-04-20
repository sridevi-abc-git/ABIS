CREATE OR REPLACE FUNCTION ABC.GetMart_PremCountyCode(bl_JOBOBJECTID number)

 return varchar2 is
-- **************************************************************************
-- File:        GETMART_PREMCOUNTYCODE.FNC  
-- Author:      CX
--
-- $Rev$  
-- $Date$
-- Last Changed By:  $Author$
--
-- Description:    
--      Returns the Premise Address Data from Mart (Corral).  
--      For both Applicatoin or License this function, 
--      pass in mart.licnese jobid  (mart.license:jobid = MART.BUSINESSLOCATIONS:JOBOBJECTID)
--        or mart.application objectid (mart.application:objectid = MART.BUSINESSLOCATIONS:JOBOBJECTID
--
-- 
-- History:
-----------------------------------------------------------------------------
--    Date                  Comment
-- 08/22/2018 TJL         Initial Check-in   
-- **************************************************************************
  t_AddressData varchar2(100);
begin
  select AD.COUNTYCODE
    into t_AddressData   
    From MART.BUSINESSLOCATIONS bl
    Join MART.ADDRESS ad on AD.OBJECTID = BL.ADDRESSOBJECTID
    Where BL.JOBOBJECTID = bl_JOBOBJECTID;
  return t_AddressData;
end GetMart_PremCountyCode;
/


GRANT EXECUTE ON ABC.GETMART_PREMCOUNTYCODE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_PREMCOUNTYCODE TO PUBLIC;
