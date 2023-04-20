CREATE OR REPLACE FORCE VIEW ABC.V_PERSON_NAME
(OBJECTID, FIRSTNAME, MIDDLENAME, LASTNAME)
BEQUEATH DEFINER
AS 
(SELECT A.objectid,  -- Created by M. Rodrigues to be able to query the database for specific names
           A.AttributeValue firstname,
           B.attributevalue middlename,
           C.attributevalue lastname
      FROM possedata.ObjectColumnData A,
           possedata.ObjectColumnData B,
           possedata.ObjectColumnData C
     WHERE     A.ColumnDefId = 327484    -- first name
           AND B.ColumnDefId = 292570    -- middle name
           AND C.ColumnDefId = 340868    -- last name
           AND a.objectid = b.objectid
           AND a.objectid = c.objectid);
