CREATE OR REPLACE FORCE VIEW SITESPECIFIC.APPLICATIONPROTESTANT
(PROTESTANTOBJECTID, APPLICATIONJOBID, USERNAME)
BEQUEATH DEFINER
AS 
select t.protestantobjectid, t.applicationjobid, t.username
    from sitespecific.ApplicationProtestant_t t
   where api.pkg_ColumnQuery.Value(t.ApplicationJobId,'CurrentUserName') = t.UserName;


GRANT SELECT ON SITESPECIFIC.APPLICATIONPROTESTANT TO POSSEEXTENSIONS;
