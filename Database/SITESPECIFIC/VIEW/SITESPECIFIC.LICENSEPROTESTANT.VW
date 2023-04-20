CREATE OR REPLACE FORCE VIEW SITESPECIFIC.LICENSEPROTESTANT
(PROTESTANTOBJECTID, LICENSEJOBID, USERNAME)
BEQUEATH DEFINER
AS 
SELECT t.protestantobjectid, t.licensejobid, t.username
     FROM sitespecific.licenseprotestant_t t
    WHERE api.pkg_columnquery.VALUE (t.licensejobid, 'CurrentUserName') =
                                                                    t.username;


GRANT SELECT ON SITESPECIFIC.LICENSEPROTESTANT TO POSSEEXTENSIONS;
