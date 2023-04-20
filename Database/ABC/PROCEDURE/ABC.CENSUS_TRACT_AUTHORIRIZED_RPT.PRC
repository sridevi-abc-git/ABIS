CREATE OR REPLACE PROCEDURE ABC.CENSUS_TRACT_AUTHORIRIZED_RPT
( p_effectiveDate DATE)
AS
BEGIN
 
WITH LICENSE_TYPES AS  -- 1. Create a logical table of license type onsale and offsale counts
( SELECT 
    LT.PremAddressCountyCode AS CountyCode
  , LTC.LicenseTypeCode AS LicenseTypeCode
  , CASE WHEN LTC.LicenseTypeCode NOT IN ('20','21','85') THEN 1 END AS "ONSALE_COUNT"
  , CASE WHEN LTC.LicenseTypeCode     IN ('20','21','85') THEN 1 END AS "OFFSALE_COUNT"
  FROM MART.LicenseType LT
  JOIN MART.PrimaryAndSecondaryLicenceType R ON R.LicenseTypeObjectID = LT.ObjectId
  JOIN MART.LicenseTypeCategory LTC ON R.LicenseceTypeCategoryObjectId = LTC.ObjectId
    AND LTC.LicenseTypeCode IN 
       ('40','41','42','47','48','49','50','51','52','57','59','60','61','63','64','67','69','70','75','76','80','81' ,'86'  -- ON-SALE TYPES
       , '20','21','85') -- OFF-SALE TYPES
  JOIN extension.JobStatusChange J ON LT.ObjectId = J.JobId
  WHERE R.Primary IS NOT NULL
    AND J.StatusName IN ('ACTIVE','SUREND','SUSPEN','R64B','SLMSHD','REVPEN')
    AND J.effectivestartdate =
         (SELECT MAX (JO.EffectiveStartDate)
            FROM extension.JobStatusChange JO
           WHERE JO.jobid = J.JobId
--         AND JO.effectivestartdate <= TO_DATE('07/31/2015','MM/DD/YYYY'))    -- Modify this effective date for each year
--         AND JO.effectivestartdate <= TO_DATE('effective_date' ,'MM/DD/YYYY'))    -- Modify this effective date for each year
           AND JO.effectivestartdate <= '31-dec-2017')    -- Modify this effective date for each year
           
  UNION ALL
           
  SELECT
   LT.PREMADDRESSCOUNTYCODE AS CountyCode
  , LTC.LicenseTypeCode LicenseType
  , CASE WHEN LTC.LicenseTypeCode NOT IN ('20','21','85') THEN 1 END AS "ON-SALE_COUNT"
  , CASE WHEN LTC.LicenseTypeCode     IN ('20','21','85') THEN 1 END AS "OFF-SALE_COUNT"
  FROM MART.licensetype LT                                          --primary
  JOIN MART.primaryandsecondarylicencetype x ON x.LICENSETYPEOBJECTID = LT.objectid
  JOIN sitespecific.sltstatuschange_t SC ON SC.relationshipid = X.RELATIONSHIPID
  JOIN MART.licensetypecategory LTC ON LTC.ObjectId = X.LICENSECETYPECATEGORYOBJECTID
  JOIN MART.licensetypecategoryrel PLT ON PLT.LICENSETYPEOBJECTID = LT.ObjectId
  WHERE X.primary IS NULL                            --secondary lt's only.
    AND SC.statusname IN ('ACTIVE','SUREND','SUSPEN','R64B', 'SLSMSHD','REVPEN')
    AND LTC.LicenseTypeCode IN
         ('40','41','42','47','48','49','50','51','52','57','59','60','61','63','64','67','69','70','75','76','80','81' ,'86' -- On sale
         ,'20','21','85') -- off sale
    AND SC.effectivestartdate =
            (SELECT MAX(SC.effectivestartdate)
               FROM sitespecific.sltstatuschange_t SC
              WHERE SC.relationshipid = x.relationshipid
--              AND SC.effectivestartdate <= TO_DATE('07/31/2015','MM/DD/YYYY'))   -- Modify this effective date for each year
--              AND SC.effectivestartdate <= TO_DATE('effective_date','MM/DD/YYYY'))   -- Modify this effective date for each year
              AND SC.effectivestartdate <= '31-dec-2017')   -- Modify this effective date for each year
)

, LICENSE_TYPE_COUNTS AS  -- 2. Aggregate counts with a group by
( SELECT 
    COUNTYCODE  
  , COUNT(ONSALE_COUNT) AS "ONSALE_COUNT"  
  , COUNT(OFFSALE_COUNT) AS "OFFSALE_COUNT"  
  FROM LICENSE_TYPES
  GROUP BY COUNTYCODE
  ORDER BY COUNTYCODE
)
-- 3. Join the above aggregation with CENSUS_TRACT_POPULATION from US Census Bureau
SELECT   
  T.COUNTYNAME as "County Name"
, CC.POPULATION as "County Population"
, ROUND(CC.POPULATION/C.ONSALE_COUNT) AS "County Ratio On Sale"
, ROUND(CC.POPULATION/C.OFFSALE_COUNT) AS "County Ratio Off Sale"
, T.TRACT as "Census Tract #"
, T.TRACT_POPULATION as "Census Tract Population" 

, TRUNC(T.TRACT_POPULATION/ROUND( CC.POPULATION/C.ONSALE_COUNT)) as "On Sale"    -- Census tract population/county on-sale ratio
, TRUNC(T.TRACT_POPULATION/ROUND( CC.POPULATION/C.OFFSALE_COUNT)) as "Off Sale"  -- Census tract population/county off-sale ratio

FROM CENSUS_TRACT_POPULATION T
JOIN LICENSE_TYPE_COUNTS C ON C.COUNTYCODE=T.COUNTYCODE
JOIN MART.CACOUNTY CC ON CC.COUNTYCODE=C.COUNTYCODE
ORDER BY T.COUNTYNAME, TO_NUMBER(T.TRACT);
END CENSUS_TRACT_AUTHORIRIZED_RPT;

/*

DESC CENSUS_TRACT_AUTHORIRIZED
SELECT * FROM CENSUS_TRACT_AUTHORIRIZED
*/
/
