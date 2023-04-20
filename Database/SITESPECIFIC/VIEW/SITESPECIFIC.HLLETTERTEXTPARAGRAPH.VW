CREATE OR REPLACE FORCE VIEW SITESPECIFIC.HLLETTERTEXTPARAGRAPH
(RELATIONSHIPID, JOBID, HLLETTERTEXTOBJECTID, LETTERTEXTCODE, LETTERTEXTDESCRIPTION, 
 LETTERTEXTTYPE, SORT, SORT1)
BEQUEATH DEFINER
AS 
select r.RelationshipId,
       r.AccusationJobId JobId,
       h.ObjectId HLLetterTextObjectId,
       r.LetterTextCode,
       r.LetterTextDescription,
       h.LetterTextType,
       r.Sort,
       h.Sort1
  from query.o_HLLetterText h
  join query.r_AccusationHLLetterText r
    on h.ObjectId = r.HLLetterTextObjectId
 where h.LetterTextType = 'PARAGRAPH'
union
select r.RelationshipId,
       r.ApplicationJobId JobId,
       h.ObjectId HLLetterTextObjectId,
       r.LetterTextCode,
       r.LetterTextDescription,
       h.LetterTextType,
       r.Sort,
       h.Sort1
  from query.o_HLLetterText h
  join query.r_ApplicationHLLetterText r
    on h.ObjectId = r.HLLetterTextObjectId
 where h.LetterTextType = 'PARAGRAPH'
union
 select r.RelationshipId,
       r.LicenseJobId JobId,
       h.ObjectId HLLetterTextObjectId,
       r.LetterTextCode,
       r.LetterTextDescription,
       h.LetterTextType,
       r.Sort,
       h.Sort1
  from query.o_HLLetterText h
  join query.r_LicenseHLLetterText r
    on h.ObjectId = r.HLLetterTextObjectId
 where h.LetterTextType = 'PARAGRAPH';


GRANT SELECT ON SITESPECIFIC.HLLETTERTEXTPARAGRAPH TO POSSEEXTENSIONS;
