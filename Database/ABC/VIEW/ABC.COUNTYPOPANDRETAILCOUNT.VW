CREATE OR REPLACE FORCE VIEW ABC.COUNTYPOPANDRETAILCOUNT
(COUNTY, RETAILTYPE, RETAILCOUNT, COUNTYPOPULATION)
BEQUEATH DEFINER
AS 
SELECT x.Area,
            x.RetailType,
            --x.LicenseType,
            COUNT (x.ObjectId) ObjectIdForCount,
            (  SELECT SUM (TO_NUMBER (C.POP2010)) AS cp
                 FROM ABC.TEMP_2010TRACT_GP_zpop c
                      -- JOIN ABC.FIPSCOUNTY f ON C.FIPS_COUNTY = F.FIPSCOUNTYCODE
                      JOIN MART.CACOUNTY f ON C.FIPS_COUNTY = F.FIPSCOUNTYCODE
                WHERE F.COUNTYNAME = x.area
             GROUP BY F.COUNTYNAME)
               CountyPop
       FROM (SELECT lt.area Area,
                    'Off-Sale' RetailType,                    --lt.RetailType,
                    ltc.LicenseTypeCode LicenseType,
                    ltc.ObjectId ObjectId
               FROM mart.licensetype lt
                    JOIN mart.primaryandsecondarylicencetype r
                       ON r.LICENSETYPEOBJECTID = lt.ObjectId
                    JOIN mart.licensetypecategory ltc
                       ON r.LICENSECETYPECATEGORYOBJECTID = ltc.ObjectId
                    JOIN extension.jobstatuschange j ON lt.ObjectId = j.jobid
              WHERE     lt.RetailType IS NOT NULL
                    AND r.primary IS NOT NULL
                    AND j.StatusName IN ('ACTIVE',
                                         'SUREND',
                                         'SUSPEN',
                                         'R64B',
                                         'SLMSHD',
                                         'REVPEN')
                    AND ltc.LicenseTypeCode IN (20, 21, 85)
                    --  and lt.area = 'FRESNO'
                    AND j.effectivestartdate =
                           (SELECT MAX (jo.effectivestartdate)
                              FROM extension.jobstatuschange jo
                             WHERE     jo.effectivestartdate < SYSDATE -- :a_Report_Date
                                   AND jo.jobid = j.jobid)
                    AND NOT EXISTS
                           (SELECT blt.RELATIONSHIPID
                              FROM mart.BranchLicenseType blt
                             WHERE blt.BranchLicenseTypeJobId = lt.ObjectId)
             UNION ALL
             -- ON SALE COUNTS
             SELECT lt.area Area,
                    'On-Sale' RetailType,                     --lt.RetailType,
                    ltc.LicenseTypeCode LicenseType,
                    ltc.ObjectId ObjectId
               FROM mart.licensetype lt
                    JOIN mart.primaryandsecondarylicencetype r
                       ON r.LICENSETYPEOBJECTID = lt.ObjectId
                    JOIN mart.licensetypecategory ltc
                       ON r.LICENSECETYPECATEGORYOBJECTID = ltc.ObjectId
                    JOIN extension.jobstatuschange j ON lt.ObjectId = j.jobid
              WHERE     lt.RetailType IS NOT NULL
                    AND r.primary IS NOT NULL
                    AND j.StatusName IN ('ACTIVE',
                                         'SUREND',
                                         'SUSPEN',
                                         'R64B',
                                         'SLMSHD',
                                         'REVPEN')
                    AND ltc.LicenseTypeCode IN (40,
                                                41,
                                                42,
                                                47,
                                                48,
                                                49,
                                                50,
                                                51,
                                                52,
                                                57,
                                                59,
                                                60,
                                                61,
                                                63,
                                                64,
                                                67,
                                                69,
                                                70,
                                                71,
                                                75,
                                                76,
                                                80,
                                                86)
                    --  and lt.area = 'FRESNO'
                    AND j.effectivestartdate =
                           (SELECT MAX (jo.effectivestartdate)
                              FROM extension.jobstatuschange jo
                             WHERE     jo.effectivestartdate < SYSDATE --  :a_Report_Date
                                   AND jo.jobid = j.jobid)
                    AND NOT EXISTS
                           (SELECT blt.RELATIONSHIPID
                              FROM mart.BranchLicenseType blt
                             WHERE blt.BranchLicenseTypeJobId = lt.ObjectId) --order by lt.area
                                                                            ) x
   GROUP BY x.Area, x.RetailType
   -- , x.LicenseType
   ORDER BY x.Area, x.RetailType
-- , x.LicenseType
;
