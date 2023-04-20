CREATE OR REPLACE FORCE VIEW SITESPECIFIC.HLLETTERTEXTMASTERCAPTION
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
 where h.LetterTextType = 'MASTER CAPTION'
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
 where h.LetterTextType = 'MASTER CAPTION'
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
 where h.LetterTextType = 'MASTER CAPTION';


GRANT SELECT ON SITESPECIFIC.HLLETTERTEXTMASTERCAPTION TO POSSEEXTENSIONS;
