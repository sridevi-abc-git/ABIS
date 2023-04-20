CREATE OR REPLACE FORCE VIEW SITESPECIFIC.ONEDAYLICENSECONDITION
(RELATIONSHIPID, ONEDAYLICENSEJOBID, CONDITIONOBJECTID, CONDITIONCODE, CONDITIONTEXT, 
 TEXTTYPE, SORT, SORT1)
BEQUEATH DEFINER
AS 
select odlc.RelationshipId,
         odlc.OneDayLicenseJobId,
         c.ObjectId ConditionObjectId,
         odlc.ConditionCode,
         odlc.ConditionText,
         c.TextType,
         odlc.Sort,
         c.Sort1
    from query.o_Condition c
    join query.r_OneDayLicenseConditions odlc
      on c.ObjectId = odlc.ConditionObjectId
   where c.TextType = 'CONDITION';
