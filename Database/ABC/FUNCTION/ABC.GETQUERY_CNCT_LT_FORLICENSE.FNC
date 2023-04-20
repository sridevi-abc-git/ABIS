CREATE OR REPLACE FUNCTION ABC.GetQuery_CNCT_LT_ForLicense(a_LicenseJobId number)
  return varchar2 is
-- **************************************************************************
-- File:        GETQUERY_CNCT_LT_FORLICENSE.FNC  
-- Author:      CX
--
-- $Rev$  
-- $Date$
-- Last Changed By:  $Author$
--
-- Description:    
--      pass in license job id
--
-- 
-- History:
-----------------------------------------------------------------------------
--    Date                  Comment
-- 08/22/2018 TJL         Initial Check-in   
-- **************************************************************************
  t_LTCodes varchar2(4000);
begin

select concatlist(t.ltcode)
into t_LTCodes
from(
      select lt.LicenseTypeCode ltcode, 'pri' sort
        from query.r_licenselicensetype llt
        join query.j_licensetype lt on lt.ObjectId = llt.LICENSETYPEJOBID
       where llt.LICENSEJOBID = a_LicenseJobId

      union all

      select ltc.LicenseTypeCode || case
               when slt.LicenseTypeCount > 0 then
                '[' || slt.LicenseTypeCount || ']'
             end ltcode,
             'sec' sort
        from query.r_licenselicensetype llt
        join query.r_licensetypeltcatsecondary slt on slt.LICENSETYPEJOBID =
                                                              llt.LICENSETYPEJOBID
        join query.o_licensetypecategory ltc on ltc.ObjectId =
                                                         slt.LICENSETYPECATEGORYOBJECTID
       where llt.LICENSEJOBID = a_LicenseJobId
       order by 2, 1) t;

  return t_LTCodes;
end GetQuery_CNCT_LT_ForLicense;
/


GRANT EXECUTE ON ABC.GETQUERY_CNCT_LT_FORLICENSE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETQUERY_CNCT_LT_FORLICENSE TO PUBLIC;
