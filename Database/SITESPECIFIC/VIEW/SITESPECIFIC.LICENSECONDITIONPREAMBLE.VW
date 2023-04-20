CREATE OR REPLACE FORCE VIEW SITESPECIFIC.LICENSECONDITIONPREAMBLE
(RELATIONSHIPID, JOBID, CONDITIONOBJECTID, CONDITIONCODE, CONDITIONTEXT, 
 TEXTTYPE, SORT, SORT1)
BEQUEATH DEFINER
AS 
SELECT ac.relationshipid, ac.licensejobid jobid,
          c.objectid conditionobjectid, ac.conditioncode, ac.conditiontext,
          c.texttype, ac.sort, c.sort1
     FROM QUERY.o_condition c JOIN QUERY.r_licensecondition ac
          ON c.objectid = ac.conditionobjectid
    WHERE c.texttype = 'PREAMBLE';


GRANT SELECT ON SITESPECIFIC.LICENSECONDITIONPREAMBLE TO POSSEEXTENSIONS;
