CREATE OR REPLACE FORCE VIEW SITESPECIFIC.ISSUECATEVENTCONDITION
(RELATIONSHIPID, ISSUECATEREREVENTAUTHPROCESSID, CONDITIONOBJECTID, CONDITIONCODE, CONDITIONTEXT, 
 TEXTTYPE, SORT, SORT1)
BEQUEATH DEFINER
AS 
select ic.RelationshipId,
         ic.IssueCatererEventAuthProcessId,
         c.ObjectId ConditionObjectId,
         ic.ConditionCode,
         ic.ConditionText,
         c.TextType,
         ic.Sort,
         c.Sort1
    from query.o_Condition c
    join query.r_IssueCatererEventCondition ic
      on c.ObjectId = ic.ConditionObjectId
   where c.TextType = 'CONDITION';
