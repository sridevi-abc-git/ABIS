CREATE OR REPLACE FORCE VIEW SITESPECIFIC.OBJECTCREATEDBYUSER
(OBJECTID, CREATEDBY)
BEQUEATH DEFINER
AS 
select o.ObjectId,
       lt.CreatedBy
  from api.Objects o
  join api.LogicalTransactions lt
    on lt.LogicalTransactionId = o.CreatedLogicalTransactionId;


GRANT SELECT ON SITESPECIFIC.OBJECTCREATEDBYUSER TO POSSEEXTENSIONS;
