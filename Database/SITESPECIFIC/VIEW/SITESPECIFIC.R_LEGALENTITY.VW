CREATE OR REPLACE FORCE VIEW SITESPECIFIC.R_LEGALENTITY
(RELATIONSHIPID, RELATIONSHIPDEFID, FROMOBJECTID, TOOBJECTID, OBJECTID, 
 NESTLEVEL)
BEQUEATH DEFINER
AS 
select r.RelationshipId,
       r.RelationshipDefId,
       r.FromObjectId,
       r.ToObjectId,
       t.ObjectId,
       level NestLevel/*,
       (select e.FirstName from query.o_LegalEntity e where e.ObjectId = r.FromOBjectId) FromName,
       (select e.FirstName from query.o_LegalEntity e where e.ObjectId = r.ToOBjectId) ToName,
       (select rd.Name from api.RelationshipDefs rd where rd.FromEndPointId = r.EndPointId) FromRelName,
       (select rd.FromEndPointName from api.RelationshipDefs rd where rd.FromEndPointId = r.EndPointId) FromEndpointName,
       (select rd.Name from api.RelationshipDefs rd where rd.ToEndPointId = r.EndPointId) ToRelName,
       (select rd.FromEndPointName from api.RelationshipDefs rd where rd.ToEndPointId = r.EndPointId) ToEndPointName*/
  from api.Relationships r
  join api.Objects f
    on f.ObjectId = r.FromObjectId,
       api.Objects t
 where t.ObjectDefId = api.pkg_ConfigQuery.ObjectDefIdForName('j_Application')
   and t.ObjectDefTypeId = 2
 start with r.ToObjectId = t.ObjectId
   and f.ObjectDefId = api.pkg_ConfigQuery.ObjectDefIdForName('o_LegalEntity')
 connect by r.ToObjectId = prior r.FromObjectId
   and r.RelationshipId != prior r.RelationshipId
   and f.ObjectDefId = api.pkg_ConfigQuery.ObjectDefIdForName('o_LegalEntity');
