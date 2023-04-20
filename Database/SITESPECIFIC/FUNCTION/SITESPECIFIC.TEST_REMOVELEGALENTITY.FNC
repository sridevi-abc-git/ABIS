CREATE OR REPLACE function SITESPECIFIC.TEST_RemoveLegalEntity(
    a_LegalEntityId                     number,
    a_ParentLegalEntities               api.udt_ObjectList
  ) return boolean is
    t_ParentLEList                      api.udt_ObjectList;
    t_TopLE                             number;
    t_PersonLECount                     number;
    t_CompanyLECount                    number;
    t_CompanyODLCount                   number;
    t_OtherCount                        number;
    t_RemoveLEResult                    boolean;
    t_IsLEStillOnAP12                   varchar2(1) := 'N';
    t_RelationshipId                    number;
    t_ApplicantToAppEP                  number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'AppApplication');
    t_LicenseeToLicEP                   number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'LegalEntityLicense');
    t_OsmToAppEP                        number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'OSMApplication');
    t_OsmLeToLicEP                      number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'OSMLicense');
    t_P12AParentToHolderEP              number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'P12AParent');
    t_P12LeToAppEP                      number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'P12Application');
    t_P12AHolderToParentEP              number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'P12AStockholder');
    t_P12LeToLicEP                      number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'P12License');
    t_PrimP12LeAppEP                    number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'PrimaryP12Application');
    t_PrimP12LeLicEP                    number := api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'PrimaryP12License');

  begin
    --FOLLOWING LINE IS TEMP TESTING CODE
    dbms_output.put_line('Evaluating for removal: ' || a_LegalEntityId);
    if sitespecific.pkg_Utils.DoesObjectExist(a_LegalEntityId) then
      -- Copy over the list, and append the current Legal Entity
      t_ParentLEList := a_ParentLegalEntities;
      t_ParentLEList.extend;
      t_ParentLEList(t_ParentLEList.count) := api.udt_Object(a_LegalEntityId);

      -- In order for a Legal Entity to be deleted, certain criteria must be met:
      -- 1) the related Person / Company must be related to another Legal Entity
      -- 2) OR the related Company must be related to a One Day License.

      -- Count of Person to Legal Entity
      select count(1)
        into t_PersonLECount
        from query.r_LegalEntityPerson lep
        join (select lep2.PersonObjectId
                from query.r_LegalEntityPerson lep2
               where lep2.LegalEntityObjectId = a_LegalEntityId) p
          on lep.PersonObjectId = p.PersonObjectId
       where lep.LegalEntityObjectId != a_LegalEntityId;

      -- Count of Company to Legal Entity
      select count(1)
        into t_CompanyLECount
        from query.r_LegalEntityCompany lec
        join (select lec2.CompanyObjectId
                from query.r_LegalEntityCompany lec2
               where lec2.LegalEntityObjectId = a_LegalEntityId) c
          on lec.CompanyObjectId = c.CompanyObjectId
       where lec.LegalEntityObjectId != a_LegalEntityId;

      -- Count of Company to One Day License
      select count(1)
        into t_CompanyODLCount
        from query.r_LegalEntityCompany lec
        join query.r_CompanyOneDayLicense codl
          on lec.CompanyObjectId = codl.CompanyObjectId
       where lec.LegalEntityObjectId = a_LegalEntityId;

       -- Count of other relationships to the Legal Entity
       select count(1)
         into t_OtherCount
         from api.Relationships r
        where r.FromObjectId = a_LegalEntityId
          and r.EndPointId in
                ( t_ApplicantToAppEP
                , t_LicenseeToLicEP
                , t_OsmToAppEP
                , t_OsmLeToLicEP
                , t_P12AParentToHolderEP
                , t_P12LeToAppEP
                , t_P12AHolderToParentEP
                , t_P12LeToLicEP
                , t_PrimP12LeAppEP
                , t_PrimP12LeLicEP );

      t_TopLE := sitespecific.pkg_LegalEntity.GetTopMostLEParent(a_LegalEntityId);
      
      if t_TopLE is not null then
        select le.P12Status
          into t_IsLEStillOnAP12
          from query.o_LegalEntity le
         where le.objectid = t_TopLE;
      end if;

      -- If the related person or company have no other relationships or a One Day License OR the Legal Entity does have any of the listed EndPoints,
      -- do not delete the Legal Entity, return false and stop removal.
      if t_PersonLECount + t_CompanyLECount + t_CompanyODLCount = 0 or t_OtherCount > 0 or t_IsLEStillOnAP12 = 'Y' then
        if api.pkg_ColumnQuery.Value(a_LegalEntityId, 'ShouldDelete') = 'Y' then
          api.pkg_ColumnUpdate.SetValue(a_LegalEntityId, 'ShouldDelete', 'N');
          return false;
        end if;
      end if;

      -- Recurse through all related Legal Entities, if removal of one of these
      -- returns false, then return false to stop all removal.
      for le in (select r.ToObjectId ObjectId
                   from api.Relationships r
                  where r.FromObjectId = a_LegalEntityId
                    and api.pkg_ColumnQuery.Value(r.ToObjectId, 'ObjectDefName') = 'o_LegalEntity'
                    and not exists (select 1
                                      from table(a_ParentLegalEntities) ple
                                     where ple.ObjectId = r.ToObjectId))
      loop
      -- Before removing a Legal Entity, make sure we haven't already removed it.
      if sitespecific.pkg_Utils.DoesObjectExist(le.ObjectId) then
        t_RemoveLEResult := sitespecific.TEST_RemoveLegalEntity(le.ObjectId, t_ParentLEList);
        if not t_RemoveLEResult then
          if api.pkg_ColumnQuery.Value(a_LegalEntityId, 'ShouldDelete') = 'Y' then
            api.pkg_ColumnUpdate.SetValue(a_LegalEntityId, 'ShouldDelete', 'N');
            return false;
          end if;
        end if;
      end if;
      end loop;

      -- We should have returned from all recursive calls at this point, and can now attempt
      -- to remove the Person / Company relationships / objects and the Legal Entity stored
      -- relationships, and finally the Legal Entity object.

      -- Remove Person / Company relationships and the objects themselves
      for pc in (select lep.PersonObjectId ObjectId
                   from query.r_LegalEntityPerson lep
                  where lep.LegalEntityObjectId = a_LegalEntityId
                    and not exists (select 1
                                      from api.Relationships r
                                     where r.FromObjectId = lep.PersonObjectId
                                       and r.ToObjectId != a_LegalEntityId)
                 union all
                 select lec.CompanyObjectId ObjectId
                   from query.r_LegalEntityCompany lec
                  where lec.LegalEntityObjectId = a_LegalEntityId
                    and not exists (select 1
                                      from api.Relationships r
                                     where r.FromObjectId = lec.CompanyObjectId
                                       and r.ToObjectId != a_LegalEntityId))
      loop
        select r.RelationshipId
          into t_RelationshipId
          from api.Relationships r
         where r.FromObjectId = pc.ObjectId
           and r.ToObjectId = a_LegalEntityId;

      -- Before removing anything, we need to make sure it still exists...
      if sitespecific.pkg_Utils.DoesObjectExist(t_RelationshipId) then
        api.pkg_RelationshipUpdate.Remove(t_RelationshipId);
      end if;
      if sitespecific.pkg_Utils.DoesObjectExist(pc.ObjectId) then
        api.pkg_ObjectUpdate.Remove(pc.ObjectId);
      end if;
      end loop;

      -- Remove stored relationships to the Legal Entity, followed by the Legal Entity object.
      -- BUT, don't remove any parent Legal Entities.
      for sr in (select r.RelationshipId
                   from api.Relationships r
                  where r.FromObjectId = a_LegalEntityId
                    and not exists (select 1
                                      from table(a_ParentLegalEntities) ple
                                     where ple.ObjectId = r.ToObjectId))
      loop
      if sitespecific.pkg_Utils.DoesObjectExist(sr.RelationshipId) then
        api.pkg_RelationshipUpdate.Remove(sr.RelationshipId);
      end if;
      end loop;

      -- Remove the Legal Entity and return true for successful deletion
    if sitespecific.pkg_Utils.DoesObjectExist(a_LegalEntityId) then
      dbms_output.put_line('DELETING: ' || a_LegalEntityId);
      api.pkg_ObjectUpdate.Remove(a_LegalEntityId);
    end if;
      return true;
    else
      return false;
    end if;
  end TEST_RemoveLegalEntity;

/
