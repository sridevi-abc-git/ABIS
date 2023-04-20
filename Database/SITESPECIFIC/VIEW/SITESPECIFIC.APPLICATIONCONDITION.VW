CREATE OR REPLACE FORCE VIEW SITESPECIFIC.APPLICATIONCONDITION
(RELATIONSHIPID, JOBID, CONDITIONOBJECTID, CONDITIONCODE, CONDITIONTEXT, 
 TEXTTYPE, SORT, SORT1)
BEQUEATH DEFINER
AS 
select ac.RelationshipId,
         ac.ApplicationJobId JobId,
         c.ObjectId ConditionObjectId,
         ac.ConditionCode,
         ac.ConditionText,
         c.TextType,
         ac.Sort,
         c.Sort1
    from query.o_Condition c
    join query.r_ApplicationCondition ac
      on c.ObjectId = ac.ConditionObjectId
   where c.TextType = 'CONDITION';


GRANT SELECT ON SITESPECIFIC.APPLICATIONCONDITION TO POSSEEXTENSIONS;
