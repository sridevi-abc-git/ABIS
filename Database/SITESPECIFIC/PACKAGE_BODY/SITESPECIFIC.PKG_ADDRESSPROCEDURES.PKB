CREATE OR REPLACE package body SITESPECIFIC.pkg_AddressProcedures as

  subtype udt_IdList is api.pkg_Definition.udt_IdList;
  subtype udt_Name is api.pkg_Definition.udt_Name;
  subtype udt_SearchResults is api.pkg_Definition.udt_SearchResults;

  type udt_Address is record (
    AddressedObjectId                   udt_Id,
    IsPrimary                           udt_Boolean,
    Suite                               varchar2(6),
    HouseNumber                         number(5),
    HouseSuffix                         varchar2(4),
    StreetNameObjectId                  udt_Id
  );

  type udt_AddressByInheritanceChain is table of udt_Address
      index by varchar2(4000);

  type udt_EndPointIdDict is table of udt_Id
      index by varchar2(61);

  type udt_ObjectDefIdDict is table of udt_Id
      index by varchar2(30);

  type udt_ObjectIdByInheritanceChain is table of udt_Id
      index by varchar2(4000);

  g_EndPointsByNames                    udt_EndPointIdDict;
  g_ObjectDefsByName                    udt_ObjectDefIdDict;

  /*---------------------------------------------------------------------------
   * EndPointIdForNames() -- PRIVATE
   *   Return the EndPointId for an ObjectDef Name and EndPoint Name.
   *-------------------------------------------------------------------------*/
  function EndPointIdForNames (
    a_ObjectDefName                     udt_Name,
    a_EndPointName                      udt_Name
  ) return udt_Id is
    t_Key                               varchar2(61);
  begin

    t_Key := upper(a_ObjectDefName) || '.' || upper(a_EndPointName);
    if not g_EndPointsByNames.exists(t_Key) then
        g_EndPointsByNames(t_Key) := api.pkg_ConfigQuery.EndPointIdForName(
            a_ObjectDefName, a_EndPointName);
    end if;

    return g_EndPointsByNames(t_Key);

  end;

  /*---------------------------------------------------------------------------
   * EndPointIdForObjectIdAndName() -- PRIVATE
   *   Return the EndPointId for an ObjectId and Name.
   *-------------------------------------------------------------------------*/
  function EndPointIdForObjectIdAndName (
    a_ObjectId                          udt_Id,
    a_Name                              udt_Name
  ) return udt_Id is
    t_ObjectDefName                     udt_Name;
  begin

    select od.Name
    into t_ObjectDefName
    from
      api.Objects o
      join api.ObjectDefs od
          on od.ObjectDefId = o.ObjectDefId
    where o.ObjectId = a_ObjectId;

    return EndPointIdForNames(t_ObjectDefName, a_Name);

  end;

  /*---------------------------------------------------------------------------
   * ObjectDefIdForName() -- PRIVATE
   *   Return the ObjectDefId for a Name.
   *-------------------------------------------------------------------------*/
  function ObjectDefIdForName (
    a_Name                              udt_Name
  ) return udt_Id is
    t_Key                               udt_Name;
  begin

    t_Key := upper(a_Name);
    if not g_ObjectDefsByName.exists(t_Key) then
        g_ObjectDefsByName(t_Key) := api.pkg_ConfigQuery.ObjectDefIdForName(
            a_Name);
    end if;

    return g_ObjectDefsByName(t_Key);

  end;

  /*---------------------------------------------------------------------------
   * Address() -- PRIVATE
   *   Load the maintained address for a given object.
   *-------------------------------------------------------------------------*/
  function Address (
    a_ObjectId                          udt_Id
  ) return udt_Address is
    t_Address                           udt_Address;
    t_StreetNameObjectIds               udt_IdList;
  begin

    t_Address.IsPrimary := api.pkg_ColumnQuery.Value(a_ObjectId, 'IsPrimary');
    t_Address.Suite := api.pkg_ColumnQuery.Value(a_ObjectId, 'StoredSuite');
    t_Address.HouseNumber := api.pkg_ColumnQuery.Value(a_ObjectId,
        'StoredHouseNum');
    t_Address.HouseSuffix := api.pkg_ColumnQuery.Value(a_ObjectId,
        'StoredHouseSuffix');
    t_StreetNameObjectIds := api.pkg_ObjectQuery.RelatedObjects(
        a_ObjectId,
        EndPointIdForNames('o_AddressingMaintainedAddress', 'StreetName'));
    if t_StreetNameObjectIds.count() > 0 then
      t_Address.StreetNameObjectId := t_StreetNameObjectIds(1);
    end if;

    return t_Address;

  end;

  /*---------------------------------------------------------------------------
   * ChainsAbove() -- PRIVATE
   *   Generate the inheritance chains above the current object.  When you get
   * to the top, add them to the chains sparse array.
   *
   * Note that the Address.AddressedObjectId is NOT set, because we won't need
   * it for chains above.
   *-------------------------------------------------------------------------*/
  procedure ChainsAbove (
    a_ObjectId                          udt_Id,
    a_AddressSoFar                      udt_Address,
    a_ChainSoFar                        varchar2,
    a_ChainsAbove         in out nocopy udt_AddressByInheritanceChain
  ) is
    t_Address                           udt_Address;
    t_AddressedObjectIds                udt_IdList;
    t_AddressSoFar                      udt_Address;
    t_MaintainedAddressObjectIds        udt_IdList;
    t_ObjectId                          udt_Id;
  begin

    t_AddressedObjectIds := api.pkg_ObjectQuery.RelatedObjects(a_ObjectId,
        EndPointIdForNames('o_AddressingMaintainedAddress', 'InheritsFrom'));
    if t_AddressedObjectIds.count() = 0 then
      -- We are at the top of the inheritance chain.  We can now construct
      -- the address chain.
      a_ChainsAbove(a_ChainSoFar) := a_AddressSoFar;
    else
      t_MaintainedAddressObjectIds := api.pkg_ObjectQuery.RelatedObjects(
          t_AddressedObjectIds(1),
          EndPointIdForNames('o_AddressingAddressedObject',
              'MaintainedAddresses'));
      for i in 1..t_MaintainedAddressObjectIds.count() loop
        t_ObjectId := t_MaintainedAddressObjectIds(i);
        t_AddressSoFar := a_AddressSoFar;
        if t_AddressSoFar.IsPrimary = 'Y'
            or t_AddressSoFar.Suite is null
            or t_AddressSoFar.HouseNumber is null
            or t_AddressSoFar.HouseSuffix is null
            or t_AddressSoFar.StreetNameObjectId is null then
          t_Address := Address(t_ObjectId);
          if t_AddressSoFar.IsPrimary = 'Y' then
            t_AddressSoFar.IsPrimary := t_Address.IsPrimary;
          end if;
          if t_AddressSoFar.Suite is null then
            t_AddressSoFar.Suite := t_Address.Suite;
          end if;
          if t_AddressSoFar.HouseNumber is null then
            t_AddressSoFar.HouseNumber := t_Address.HouseNumber;
          end if;
          if t_AddressSoFar.HouseSuffix is null then
            t_AddressSoFar.HouseSuffix := t_Address.HouseSuffix;
          end if;
          if t_AddressSoFar.StreetNameObjectId is null then
            t_AddressSoFar.StreetNameObjectId := t_Address.StreetNameObjectId;
          end if;
        end if;

        ChainsAbove(t_ObjectId, t_AddressSoFar,
            t_ObjectId || ',' || a_ChainSoFar, a_ChainsAbove);
      end loop;
    end if;

  end;

  /*---------------------------------------------------------------------------
   * ChainsBelow() -- PRIVATE
   *   Generate the inheritance chains below the current object.  When you get
   * to the bottom, add them to the chains sparse array.
   *-------------------------------------------------------------------------*/
  procedure ChainsBelow (
    a_ObjectId                          udt_Id,
    a_AddressSoFar                      udt_Address,
    a_ChainSoFar                        varchar2,
    a_ChainsBelow         in out nocopy udt_AddressByInheritanceChain
  ) is
    t_Address                           udt_Address;
    t_AddressedObjectIds                udt_IdList;
    t_AddressSoFar                      udt_Address;
    t_Chain                             varchar2(4000);
    t_MaintainedAddressObjectIds        udt_IdList;
    t_ObjectId                          udt_Id;
  begin

    t_AddressedObjectIds := api.pkg_ObjectQuery.RelatedObjects(a_ObjectId,
        EndPointIdForNames('o_AddressingMaintainedAddress', 'AddressedObject'));
    t_MaintainedAddressObjectIds := api.pkg_ObjectQuery.RelatedObjects(
        t_AddressedObjectIds(1),
        EndPointIdForNames('o_AddressingAddressedObject', 'Descendants'));
    for i in 1..t_MaintainedAddressObjectIds.count() loop
      t_ObjectId := t_MaintainedAddressObjectIds(i);

      -- We need the AddressedObjectId of this descendant maintained address.
      t_AddressedObjectIds := api.pkg_ObjectQuery.RelatedObjects(t_ObjectId,
          EndPointIdForNames('o_AddressingMaintainedAddress', 'AddressedObject'));
      t_AddressSoFar := a_AddressSoFar;
      t_AddressSoFar.AddressedObjectId := t_AddressedObjectIds(1);
      t_Address := Address(t_ObjectId);
      if t_Address.IsPrimary = 'N' then
        t_AddressSoFar.IsPrimary := 'N';
      end if;
      if t_Address.Suite is not null then
        t_AddressSoFar.Suite := t_Address.Suite;
      end if;
      if t_Address.HouseNumber is not null then
        t_AddressSoFar.HouseNumber := t_Address.HouseNumber;
      end if;
      if t_Address.HouseSuffix is not null then
        t_AddressSoFar.HouseSuffix := t_Address.HouseSuffix;
      end if;
      if t_Address.StreetNameObjectId is not null then
        t_AddressSoFar.StreetNameObjectId := t_Address.StreetNameObjectId;
      end if;

      if a_ChainSoFar is null then
        t_Chain := t_ObjectId;
      else
        t_Chain := a_ChainSoFar || ',' || t_ObjectId;
      end if;

      -- We always include all intermediate results for chains below.
      a_ChainsBelow(t_Chain) := t_AddressSoFar;

      ChainsBelow(t_ObjectId, t_AddressSoFar, t_Chain, a_ChainsBelow);
    end loop;

  end;

  /*---------------------------------------------------------------------------
   * RemovePrimaryAddress() -- PRIVATE
   *   Remove the Primary Address indicator and relationship for a History
   * object.
   *-------------------------------------------------------------------------*/
  procedure RemovePrimaryAddress (
    a_HistoryObjectId                   udt_Id
  ) is
    t_PrimaryAddressEndPointId          udt_Id;
    t_PrimaryAddressRelIds              udt_IdList;
  begin

    t_PrimaryAddressEndPointId := EndPointIdForNames(
        'o_AddressingAddressHistory', 'PrimaryAddress');

    select RelationshipId
    bulk collect into t_PrimaryAddressRelIds
    from api.Relationships
    where FromObjectId = a_HistoryObjectId
      and EndPointId = t_PrimaryAddressEndPointId;

    pkg_Debug.PutLine('  There are currently '
        || t_PrimaryAddressRelIds.count()
        || ' primary address relationships from history object '
        || a_HistoryObjectId || '.');

    for i in 1..t_PrimaryAddressRelIds.count() loop
      api.pkg_RelationshipUpdate.Remove(t_PrimaryAddressRelIds(i));
    end loop;
    api.pkg_ColumnUpdate.SetValue(a_HistoryObjectId, 'IsPrimary', 'N');

  end;

  /*---------------------------------------------------------------------------
   * SetAddressHistory() -- PRIVATE
   *   Create or update the Address History row indicated.
   *-------------------------------------------------------------------------*/
  procedure SetAddressHistory (
    a_ObjectId                          udt_Id,
    a_AddressedObjectId                 udt_Id,
    a_Chain                             varchar2,
    a_AddressAbove                      udt_Address,
    a_AddressBelow                      udt_Address,
    a_ObjectIdsByInheritanceChain
                          in out nocopy udt_ObjectIdByInheritanceChain
  ) is
    t_Chain                             varchar2(4000);
    t_Count                             pls_integer;
    t_HistoryObjectId                   udt_Id;
    t_MaintainedAddressObjectId         udt_Id;
    t_Pos                               pls_integer;
    t_PrimaryAddressEndPointId          udt_Id;
    t_RelationshipId                    udt_Id;
    t_StreetNameEndPointId              udt_Id;
    t_StreetNameObjectIds               udt_IdList;
    t_StreetNameRelationshipIds         udt_IdList;
  begin

    if a_ObjectIdsByInheritanceChain.exists(a_Chain) then
      t_HistoryObjectId := a_ObjectIdsByInheritanceChain(a_Chain);
      pkg_Debug.PutLine('  AddressHistory object ' || t_HistoryObjectId
          || ' exists for chain "' || a_Chain || '".');
      a_ObjectIdsByInheritanceChain.delete(a_Chain);
    else
      pkg_Debug.PutLine('  No AddressHistory object for chain "' || a_Chain
          || '"; creating one.');
      t_HistoryObjectId := api.pkg_ObjectUpdate.New(
          ObjectDefIdForName('o_AddressingAddressHistory'));
      pkg_Debug.PutLine('  New t_HistoryObjectId: ' || t_HistoryObjectId);

      t_Chain := a_Chain;
      while t_Chain is not null loop
        t_Pos := instr(t_Chain, ',');
        if t_Pos > 0 then
          t_MaintainedAddressObjectId := substr(t_Chain, 1, t_Pos - 1);
          t_Chain := substr(t_Chain, t_Pos + 1);
        else
          t_MaintainedAddressObjectId := t_Chain;
          t_Chain := null;
        end if;
        pkg_Debug.PutLine('  Adding History rel between Maint Addr obj '
            || t_MaintainedAddressObjectId || ' and History obj '
            || t_HistoryObjectId);
        t_RelationshipId := api.pkg_RelationshipUpdate.New(
            EndPointIdForNames('o_AddressingMaintainedAddress', 'AddressHistory'),
            t_MaintainedAddressObjectId, t_HistoryObjectId);
      end loop;

      pkg_Debug.PutLIne('  Adding History rel between Addr obj '
          || a_AddressedObjectId || ' and History obj ' || t_HistoryObjectId);
      t_RelationshipId := api.pkg_RelationshipUpdate.New(
          EndPointIdForNames('o_AddressingAddressedObject', 'AddressHistory'),
          a_AddressedObjectId, t_HistoryObjectId);

      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectId, 'InheritanceChain',
          a_Chain);
    end if;

    t_PrimaryAddressEndPointId := EndPointIdForNames(
        'o_AddressingAddressHistory', 'PrimaryAddress');

    select count(*)
    into t_Count
    from api.Relationships
    where FromObjectId = t_HistoryObjectId
      and EndPointId = t_PrimaryAddressEndPointId;

    pkg_Debug.PutLine('  There are currently ' || t_Count
        || ' primary address relationships from history object '
        || t_HistoryObjectId || '.');

    if a_AddressAbove.IsPrimary = 'Y'
        and a_AddressBelow.IsPrimary = 'Y' then
      pkg_Debug.PutLine('  This is the primary history address.');
      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectId, 'IsPrimary', 'Y');
      if t_Count = 0 then
        t_RelationshipId := api.pkg_RelationshipUpdate.New(
            EndPointIdForNames('o_AddressingAddressHistory', 'PrimaryAddress'),
            t_HistoryObjectId, a_AddressedObjectId);
      end if;
    else
      pkg_Debug.PutLine('  This is not a primary history address.');
      RemovePrimaryAddress(t_HistoryObjectId);
    end if;
    if a_AddressBelow.Suite is null then
      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectId, 'StoredSuite',
          a_AddressAbove.Suite);
    else
      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectId, 'StoredSuite',
          a_AddressBelow.Suite);
    end if;
    if a_AddressBelow.HouseNumber is null then
      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectId, 'StoredHouseNum',
          a_AddressAbove.HouseNumber);
    else
      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectId, 'StoredHouseNum',
          a_AddressBelow.HouseNumber);
    end if;
    if a_AddressBelow.HouseSuffix is null then
      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectId, 'StoredHouseSuffix',
          a_AddressAbove.HouseSuffix);
    else
      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectId, 'StoredHouseSuffix',
          a_AddressBelow.HouseSuffix);
    end if;

    t_StreetNameEndPointId := EndPointIdForNames('o_AddressingAddressHistory',
        'StreetName');

    select
      RelationshipId,
      ToObjectId
    bulk collect into
      t_StreetNameRelationshipIds,
      t_StreetNameObjectIds
    from api.Relationships
    where FromObjectId = t_HistoryObjectId
      and EndPointId = t_StreetNameEndPointId;

    if a_AddressBelow.StreetNameObjectId is null then
      if a_AddressAbove.StreetNameObjectId is null then
        for i in 1..t_StreetNameRelationshipIds.count() loop
          api.pkg_RelationshipUpdate.Remove(t_StreetNameRelationshipIds(i));
        end loop;
      else
        if t_StreetNameObjectIds.count() > 0
            and a_AddressAbove.StreetNameObjectId != t_StreetNameObjectIds(1)
            then
          api.pkg_RelationshipUpdate.Remove(t_StreetNameRelationshipIds(1));
        end if;
        if t_StreetNameObjectIds.count() = 0
            or a_AddressAbove.StreetNameObjectId != t_StreetNameObjectIds(1)
            then
          t_RelationshipId := api.pkg_RelationshipUpdate.New(
              EndPointIdForNames('o_AddressingAddressHistory', 'StreetName'),
              t_HistoryObjectId, a_AddressAbove.StreetNameObjectId);
        end if;
      end if;
    else
      if a_AddressBelow.StreetNameObjectId is null then
        for i in 1..t_StreetNameRelationshipIds.count() loop
          api.pkg_RelationshipUpdate.Remove(t_StreetNameRelationshipIds(i));
        end loop;
      else
        if t_StreetNameObjectIds.count() > 0
            and a_AddressBelow.StreetNameObjectId != t_StreetNameObjectIds(1)
            then
          api.pkg_RelationshipUpdate.Remove(t_StreetNameRelationshipIds(1));
        end if;
        if t_StreetNameObjectIds.count() = 0
            or a_AddressBelow.StreetNameObjectId != t_StreetNameObjectIds(1)
            then
          t_RelationshipId := api.pkg_RelationshipUpdate.New(
              EndPointIdForNames('o_AddressingAddressHistory', 'StreetName'),
              t_HistoryObjectId, a_AddressBelow.StreetNameObjectId);
        end if;
      end if;
    end if;

  end;

  /*---------------------------------------------------------------------------
   * AddressedObjectDeleting() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure AddressedObjectDeleting (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  ) is
    t_Count                             pls_integer;
    t_EndPointId                        udt_Id;
  begin

    t_EndPointId := EndPointIdForNames('o_AddressedObject', 'Descendants');

    select count(*)
    into t_Count
    from api.Relationships
    where FromObjectId = a_ObjectId
      and EndPointId = t_EndPointId
      and rownum <= 1;

    if t_Count > 0 then
      api.pkg_Errors.QueueBusinessError('You may not delete '
          || api.pkg_ColumnQuery.Value(a_ObjectId, 'DisplayFormat')
          || ' because other objects with addresses depend on its address.');
    end if;

  end;

  /*---------------------------------------------------------------------------
   * AddressHistoryChanged() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure AddressHistoryChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  ) is
    t_AddressedObjectId                 udt_Id;
    t_ExtraObjectIds                    varchar2(4000);
    t_InheritanceChain                  varchar2(4000);
    t_MaintainedAddressObjectIds        udt_IdList;
    t_MissingObjectIds                  varchar2(4000);
    t_ObjectId                          udt_Id;
    t_ObjectIdSparseArray               udt_IdList;
    t_Pos                               pls_integer;
    t_SourceObjectId                    udt_Id;
  begin

    t_MaintainedAddressObjectIds := api.pkg_ObjectQuery.RelatedObjects(
        a_ObjectId,
        EndPointIdForNames('o_AddressingAddressHistory', 'MaintainedAddresses'));
    for i in 1..t_MaintainedAddressObjectIds.count() loop
      t_ObjectIdSparseArray(t_MaintainedAddressObjectIds(i)) := null;
    end loop;

    t_InheritanceChain := api.pkg_ColumnQuery.Value(a_ObjectId,
        'InheritanceChain');
    while t_InheritanceChain is not null loop
      t_Pos := instr(t_InheritanceChain, ',');
      if t_Pos > 0 then
        t_ObjectId := to_number(substr(t_InheritanceChain, 1, t_Pos - 1));
        t_InheritanceChain := substr(t_InheritanceChain, t_Pos + 1);
      else
        t_ObjectId := to_number(t_InheritanceChain);
        t_InheritanceChain := null;
      end if;

      if t_ObjectIdSparseArray.exists(t_ObjectId) then
        t_ObjectIdSparseArray.delete(t_ObjectId);
      else
        if t_ExtraObjectIds is null then
          t_ExtraObjectIds := to_char(t_ObjectId);
        else
          t_ExtraObjectIds := t_ExtraObjectIds || ', ' || t_ObjectId;
        end if;
      end if;
    end loop;
    if t_ObjectIdSparseArray.count() != 0 then
      t_ObjectId := t_ObjectIdSparseArray.first();
      while t_ObjectId is not null loop
        if t_MissingObjectIds is null then
          t_MissingObjectIds := to_char(t_ObjectId);
        else
          t_MissingObjectIds := t_MissingObjectIds || ', ' || t_ObjectId;
        end if;
        t_ObjectId := t_ObjectIdSparseArray.next(t_ObjectId);
      end loop;
    end if;
    if t_MissingObjectIds is not null or t_ExtraObjectIds is not null then
      api.pkg_Errors.RaiseError(-20000,
          'Invalid InheritanceChain: In related list, but not in chain: "'
          || t_MissingObjectIds || '".  In chain, but not in related list: "'
          || t_ExtraObjectIds || '".');
    end if;

    -- Set the FormattedAddress.
    api.pkg_ColumnUpdate.SetValue(a_ObjectId, 'FormattedAddress',
        api.pkg_ColumnQuery.Value(a_ObjectId, 'FormattedAddressExpr'));

    -- If this is the primary address, we need to recalculate the
    -- SourceObjectTitle value of the AddressedObject, because it may well
    -- include the primary address.
    if api.pkg_ColumnQuery.Value(a_ObjectId, 'IsPrimary') = 'Y' then
      t_AddressedObjectId := api.pkg_ObjectQuery.RelatedObjects(a_ObjectId,
          EndPointIdForNames('o_AddressingAddressHistory', 'AddressedObject')
          )(1);
      t_SourceObjectId := api.pkg_ColumnQuery.NumericValue(
          t_AddressedObjectId, 'SourceObjectId');
      api.pkg_ColumnUpdate.SetValue(t_AddressedObjectId, 'SourceObjectTitle',
          api.pkg_ObjectQuery.GetTitle(t_SourceObjectId));
    end if;

  end;

  /*---------------------------------------------------------------------------
   * AddressSearch() -- PUBLIC
   *   Search for objects by address.  For use with POSSE client-server and
   * Outrider.
   *-------------------------------------------------------------------------*/
  procedure AddressSearch (
    a_StreetName                        varchar2,
    a_LowHouseNumber                    number,
    a_HighHouseNumber                   number,
    a_HouseSuffix                       varchar2,
    a_Suite                             varchar2,
    a_ExactMatch                        udt_Boolean,
    a_ObjectList                    out api.udt_ObjectList
  ) is
    t_Index                             pls_integer := 0;
    t_ObjectId                          udt_Id;
    t_SearchResults                     udt_SearchResults;
  begin
    pkg_Debug.PutLine('AddressSearch:');
    pkg_Debug.PutLine('  a_StreetName: "' || a_StreetName || '"');
    pkg_Debug.PutLine('  a_LowHouseNumber: ' || a_LowHouseNumber);
    pkg_Debug.PutLine('  a_HighHouseNumber: ' || a_HighHouseNumber);
    pkg_Debug.PutLine('  a_HouseSuffix: "' || a_HouseSuffix || '"');
    pkg_Debug.PutLine('  a_Suite: "' || a_Suite || '"');
    pkg_Debug.PutLine('  a_ExactMatch: "' || a_ExactMatch || '"');

    if a_StreetName is null then
      api.pkg_Errors.QueueBusinessError('When doing an address search, '
          || 'you must enter at least part of the street name.');
      api.pkg_Errors.RaiseQueuedErrors();
    end if;

    a_ObjectList := api.udt_ObjectList();

    if not api.pkg_Search.IntersectByRelColumnValue(
        'o_AddressingAddressHistory', 'StreetName', 'FormattedName',
        a_StreetName || '%', t_SearchResults) then
      return;
    end if;
    if a_LowHouseNumber is not null or a_HighHouseNumber is not null then
      if not api.pkg_Search.IntersectByColumnValue(
          'o_AddressingAddressHistory', 'StoredHouseNum', a_LowHouseNumber,
          a_HighHouseNumber, t_SearchResults) then
        return;
      end if;
    end if;
    if a_Suite is not null then
      if not api.pkg_Search.IntersectByColumnValue(
          'o_AddressingAddressHistory', 'StoredSuite', a_Suite,
          t_SearchResults) then
        return;
      end if;
    end if;
    if a_HouseSuffix is not null then
      if not api.pkg_Search.IntersectByColumnValue(
          'o_AddressingAddressHistory', 'StoredHouseSuffix', a_HouseSuffix,
          t_SearchResults) then
        return;
      end if;
    end if;

    pkg_Debug.PutLine('Before exact match processing (if any), '
        || t_SearchResults.ObjectIdSparseArray.count()
        || ' address history objects found.');

    if a_ExactMatch = 'Y'
        and (a_LowHouseNumber is null and a_HighHouseNumber is null
            or a_HouseSuffix is null
            or a_Suite is null) then
      t_ObjectId := t_SearchResults.ObjectIdSparseArray.first();
      while t_ObjectId is not null loop
        if a_LowHouseNumber is null
            and api.pkg_ColumnQuery.Value(t_ObjectId, 'StoredHouseNum') is not null then
          t_SearchResults.ObjectIdSparseArray.delete(t_ObjectId);
        elsif a_HouseSuffix is null
            and api.pkg_ColumnQuery.Value(t_ObjectId, 'StoredHouseSuffix') is not null then
          t_SearchResults.ObjectIdSparseArray.delete(t_ObjectId);
        elsif a_Suite is null
            and api.pkg_ColumnQuery.Value(t_ObjectId, 'StoredSuite') is not null then
          t_SearchResults.ObjectIdSparseArray.delete(t_ObjectId);
        end if;

        -- Even if t_ObjectId is deleted, this gets the next one in sequence.
        t_ObjectId := t_SearchResults.ObjectIdSparseArray.next(t_ObjectId);
      end loop;
    end if;

    pkg_Debug.PutLine('After exact match processing (if any), '
        || t_SearchResults.ObjectIdSparseArray.count()
        || ' address history objects found.');

    a_ObjectList.extend(t_SearchResults.ObjectIdSparseArray.count());
    t_ObjectId := t_SearchResults.ObjectIdSparseArray.first();
    while t_ObjectId is not null loop
      t_Index := t_Index + 1;
      a_ObjectList(t_Index) := api.udt_Object(t_ObjectId);
      t_ObjectId := t_SearchResults.ObjectIdSparseArray.next(t_ObjectId);
    end loop;

  end;

  /*---------------------------------------------------------------------------
   * MaintainedAddressChanged() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure MaintainedAddressChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date,
    a_IsPrimary                         udt_Boolean
  ) is
    t_Address                           udt_Address;
    t_AddressAbove                      udt_Address;
    t_AddressedObjectId                 udt_Id;
    t_Chain                             varchar2(4000);
    t_ChainAbove                        varchar2(4000);
    t_ChainBelow                        varchar2(4000);
    t_ChainsAbove                       udt_AddressByInheritanceChain;
    t_ChainsBelow                       udt_AddressByInheritanceChain;
    t_Count                             pls_integer;
    t_EndPointId                        udt_Id;
    t_HistoryObjectId                   udt_Id;
    t_HistoryObjectIds                  udt_IdList;
    t_InheritsFromObjectId              udt_Id;
    t_MaintainedAddrObjectIds           udt_IdList;
    t_ObjectId                          udt_Id;
    t_ObjectIdsByInheritanceChain       udt_ObjectIdByInheritanceChain;
    t_PrimaryAddressObjectIds           udt_IdList;
  begin

    pkg_Debug.PutLine('pkg_AddressProcedures.MaintainedAddressChanged');
    pkg_Debug.PutLine('  a_ObjectId: ' || a_ObjectId);
    pkg_Debug.PutLine('  a_IsPrimary: ' || a_IsPrimary);

    -- If this object uses inherited addressing, its ancestor must have at
    -- least one MaintainedAddress object.
    t_EndPointId := EndPointIdForNames('o_AddressingMaintainedAddress',
            'InheritsFrom');
    begin
      select ToObjectId
      into t_InheritsFromObjectId
      from api.Relationships
      where FromObjectId = a_ObjectId
        and EndPointId = t_EndPointId;
    exception
    when no_data_found then
      t_InheritsFromObjectId := null;  -- Directly addressed
    end;

    if t_InheritsFromObjectId is not null then
      t_EndPointId := EndPointIdForNames('o_AddressingAddressedObject',
            'MaintainedAddresses');

      select count(*)
      into t_Count
      from api.Relationships
      where FromObjectId = t_InheritsFromObjectId
        and EndPointId = t_EndPointId
        and rownum <= 1;

      if t_Count = 0 then
        api.pkg_Errors.QueueBusinessError('Cannot create this address because '
            || api.pkg_ObjectQuery.GetTitle(t_InheritsFromObjectId)
            || ' does not have an address.');
      end if;
    end if;

    api.pkg_Errors.RaiseQueuedErrors();

    -- Now that the sanity checks passed, make the necessary database changes.
    t_AddressedObjectId := api.pkg_ObjectQuery.RelatedObjects(a_ObjectId,
        EndPointIdForNames('o_AddressingMaintainedAddress', 'AddressedObject')
        )(1);
    pkg_Debug.PutLine('  t_AddressedObjectId: ' || t_AddressedObjectId);

    -- If the IsPrimary flag is set, set all other addresses from the same
    -- addressed object to be not primary.
    if a_IsPrimary = 'Y' then
      pkg_Debug.PutLine( '  Ensuring that no other maintained addresses are primary.');
      t_MaintainedAddrObjectIds := api.pkg_ObjectQuery.RelatedObjects(
          t_AddressedObjectId,
          EndPointIdForNames('o_AddressingAddressedObject', 'MaintainedAddresses'));
      for i in 1..t_MaintainedAddrObjectIds.count() loop
        t_ObjectId := t_MaintainedAddrObjectIds(i);
        pkg_Debug.PutLine('  Checking Maintained Address ' || t_ObjectId);
        if t_ObjectId != a_ObjectId then
          pkg_Debug.PutLine('  Setting maintained address ' || t_ObjectId ||
              ' to not be primary.');
          t_HistoryObjectIds := api.pkg_ObjectQuery.RelatedObjects(t_ObjectId,
              EndPointIdForNames('o_AddressingMaintainedAddress', 'AddressHistory'));
          for j in 1..t_HistoryObjectIds.count() loop
            t_HistoryObjectId := t_HistoryObjectIds(j);
            if api.pkg_ColumnQuery.Value(t_HistoryObjectId, 'IsPrimary') = 'Y' then
              RemovePrimaryAddress(t_HistoryObjectId);
            end if;
          end loop;
        end if;
      end loop;
    end if;

    -- Denormalize the Address History records.
    t_HistoryObjectIds := api.pkg_ObjectQuery.RelatedObjects(a_ObjectId,
        EndPointIdForNames('o_AddressingMaintainedAddress', 'AddressHistory'));
    for i in 1..t_HistoryObjectIds.count() loop
      t_ObjectIdsByInheritanceChain(
          api.pkg_ColumnQuery.Value(t_HistoryObjectIds(i), 'InheritanceChain'))
          := t_HistoryObjectIds(i);
    end loop;

    t_Address := Address(a_ObjectId);
    ChainsAbove(a_ObjectId, t_Address, a_ObjectId, t_ChainsAbove);
    ChainsBelow(a_ObjectId, t_Address, null, t_ChainsBelow);

    -- Note that there will always be at least one item in t_ChainsAbove, but
    -- there may not be any in t_ChainsBelow.
    t_ChainAbove := t_ChainsAbove.first();
    while t_ChainAbove is not null loop
      t_AddressAbove := t_ChainsAbove(t_ChainAbove);

      -- First, we must process the chain above by itself, because this is a
      -- valid chain.  We set the IsPrimary of the dummy "address below" to 'Y'
      -- because that way if the chain above is primary, a primary address
      -- history record will be created.
      t_Address := null;
      t_Address.IsPrimary := 'Y';
      SetAddressHistory(a_ObjectId, t_AddressedObjectId, t_ChainAbove,
          t_AddressAbove, t_Address, t_ObjectIdsByInheritanceChain);

      t_ChainBelow := t_ChainsBelow.first();
      -- Then, we process it with all chains below.
      while t_ChainBelow is not null loop
        SetAddressHistory(a_ObjectId,
            t_ChainsBelow(t_ChainBelow).AddressedObjectId,
            t_ChainAbove || ',' || t_ChainBelow, t_AddressAbove,
            t_ChainsBelow(t_ChainBelow), t_ObjectIdsByInheritanceChain);

        t_ChainBelow := t_ChainsBelow.next(t_ChainBelow);
      end loop;

      t_ChainAbove := t_ChainsAbove.next(t_ChainAbove);
    end loop;

    -- After all of this, any objects left in t_ObjectIdsByInheritanceChain are
    -- no longer relevant, and must be deleted.
    t_Chain := t_ObjectIdsByInheritanceChain.first();
    while t_Chain is not null loop
      t_HistoryObjectId := t_ObjectIdsByInheritanceChain(t_Chain);
      pkg_Debug.PutLine('  AddressHistory object ' || t_HistoryObjectId
          || ' being removed for chain "' || t_Chain
          || '", because that chain no longer exists.');

      select count(*)
      into t_Count
      from api.Objects
      where ObjectId = t_HistoryObjectId;

      if t_Count = 0 then
        pkg_Debug.PutLine(
            '    Object no longer exists; don''t have to remove it.');
      else
        api.pkg_ObjectUpdate.Remove(t_HistoryObjectId);
      end if;

      t_Chain := t_ObjectIdsByInheritanceChain.next(t_Chain);
    end loop;

  end;

  /*---------------------------------------------------------------------------
   * MaintainedAddressDeleting() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure MaintainedAddressDeleting (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date,
    a_IsPrimary                         udt_Boolean
  ) is
    t_AddressedObjectId                 udt_Id;
    t_Count                             pls_integer;
    t_EndPointId                        udt_Id;
  begin

    pkg_Debug.PutLine('pkg_AddressProcedures.MaintainedAddressDeleting');
    pkg_Debug.PutLine('  a_ObjectId: ' || a_ObjectId);
    pkg_Debug.PutLine('  a_IsPrimary: ' || a_IsPrimary);

    t_AddressedObjectId := api.pkg_ObjectQuery.RelatedObjects(a_ObjectId,
        EndPointIdForNames('o_AddressingMaintainedAddress', 'AddressedObject'))(1);
    pkg_Debug.PutLine('  t_AddressedObjectId: ' || t_AddressedObjectId);

    t_EndPointId := EndPointIdForNames('o_AddressingAddressedObject',
        'MaintainedAddresses');

    -- Is this the last MaintainedAddress row for this object?
    select count(*)
    into t_Count
    from api.Relationships
    where FromObjectId = t_AddressedObjectId
      and EndPointId = t_EndPointId
      and rownum <= 2;

    if t_Count = 1 then
      -- Yes, it's the last one.  Do any addresses inherit from this one?
      t_EndPointId := EndPointIdForNames('o_AddressingAddressedObject',
          'Descendants');

      select count(*)
      into t_Count
      from api.Relationships
      where FromObjectId = t_AddressedObjectId
        and EndPointId = t_EndPointId
        and rownum <= 1;

      if t_Count > 0 then
        -- Yes, at least one address inherits from this one.
        -- Note that we will not list all the descendants here, because it
        -- could be a large list.
        api.pkg_Errors.QueueBusinessError('This address cannot be deleted '
            || 'because it is the last one on this object, and there is at '
            || 'least one address that inherits from it.');
      end if;
    elsif t_Count > 1 then
      -- No, there are at least two MaintainedAddress rows.
      if a_IsPrimary = 'Y' then
        api.pkg_Errors.QueueBusinessError('This address cannot be deleted '
            || 'because it is the primary address.  You must first designate '
            || 'another address to be primary before this one can be deleted.');
      end if;
    else
      -- This should never happen.
      api.pkg_Errors.RaiseError(-20000, 'api.Relationships has no rows where '
          || 'FromObjectId is ' || t_AddressedObjectId || ' and '
          || 'EndPointId is ' || t_EndPointId || ' (MaintainedAddresses).  '
          || 'There should be at least one row where ToObjectId is '
          || a_ObjectId || ', or we wouldn''t even be in this procedure!');
    end if;

    api.pkg_Errors.RaiseQueuedErrors();

    pkg_Debug.PutLine('It is safe to delete this Maintained Address row.');

  end;

  /*---------------------------------------------------------------------------
   * ObjectWithAddressingChanged() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure ObjectWithAddressingChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  ) is
    t_AddressedObjects                  udt_IdList;
    t_EndPointId                        udt_Id;
    t_RelationshipId                    udt_Id;
  begin

    t_EndPointId := EndPointIdForObjectIdAndName(a_ObjectId,
        'AddressedObject');
    t_AddressedObjects := api.pkg_ObjectQuery.RelatedObjects(a_ObjectId,
        t_EndPointId);
    if t_AddressedObjects.count() = 0 then
      t_AddressedObjects(1) := api.pkg_ObjectUpdate.New(
          ObjectDefIdForName('o_AddressingAddressedObject'));
      t_RelationshipId := api.pkg_RelationshipUpdate.New(t_EndPointId,
          a_ObjectId, t_AddressedObjects(1));
    end if;

    api.pkg_ColumnUpdate.SetValue(t_AddressedObjects(1), 'SourceObjectId',
        a_ObjectId);
    api.pkg_ColumnUpdate.SetValue(t_AddressedObjects(1), 'SourceComponentType',
        api.pkg_ColumnQuery.Value(a_ObjectId, 'ObjectDefDescription'));
    api.pkg_ColumnUpdate.SetValue(t_AddressedObjects(1), 'SourceObjectTitle',
        api.pkg_ObjectQuery.GetTitle(a_ObjectId));

  end;

  /*---------------------------------------------------------------------------
   * StreetNameChanged() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure StreetNameChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  ) is
    t_HistoryObjectIds                  udt_IdList;
    t_FormattedName                     varchar2(83);
  begin

    t_FormattedName := api.pkg_ColumnQuery.Value(a_ObjectId, 'FormattedNameExpr');
    if t_FormattedName is null then
      api.pkg_Errors.QueueBusinessError('You must supply a name.');
    end if;

    api.pkg_ColumnUpdate.SetValue(a_ObjectId, 'FormattedName',
        t_FormattedName);

    -- Find all Address History objects that use the Street Name, and set their
    -- FormattedAddress.
    t_HistoryObjectIds := api.pkg_ObjectQuery.RelatedObjects(a_ObjectId,
        EndPointIdForNames('o_AddressingStreetName', 'AddressHistory'));
    for i in 1..t_HistoryObjectIds.count() loop
      api.pkg_ColumnUpdate.SetValue(t_HistoryObjectIds(i), 'FormattedAddress',
          api.pkg_ColumnQuery.Value(t_HistoryObjectIds(i),
              'FormattedAddressExpr'));
    end loop;

  end;

  /*---------------------------------------------------------------------------
   * StreetNameComponentChanged() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure StreetNameComponentChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  ) is
    t_EndPointId                        udt_Id;
  begin

    t_EndPointId := EndPointIdForObjectIdAndName(a_ObjectId, 'StreetNames');

    for o in (
        select ToObjectId
        from api.Relationships
        where FromObjectId = a_ObjectId
          and EndPointId = t_EndPointId
        ) loop
      api.pkg_ObjectUpdate.Verify(o.ToObjectId);
    end loop;

  end;

  /*---------------------------------------------------------------------------
   * StreetNameComponentDeleting() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure StreetNameComponentDeleting (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  ) is
    t_Count                             pls_integer;
    t_EndPointId                        udt_Id;
  begin

    t_EndPointId := EndPointIdForObjectIdAndName(a_ObjectId, 'StreetNames');

    select count(*)
    into t_Count
    from api.Relationships
    where FromObjectId = a_ObjectId
      and EndPointId = t_EndPointId
      and rownum <= 1;

    if t_Count > 0 then
      api.pkg_Errors.QueueBusinessError('You may not delete '
          || api.pkg_ObjectQuery.GetTitle(a_ObjectId)
          || ' because street names use it.');
    end if;

  end;

  /*---------------------------------------------------------------------------
   * StreetNameDeleting() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure StreetNameDeleting (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  ) is
    t_Count                             pls_integer;
    t_EndPointId                        udt_Id;
  begin

    t_EndPointId := EndPointIdForNames('o_AddressingStreetName',
        'MaintainedAddresses');

    select count(*)
    into t_Count
    from api.Relationships
    where FromObjectId = a_ObjectId
      and EndPointId = t_EndPointId
      and rownum <= 1;

    if t_Count > 0 then
      api.pkg_Errors.QueueBusinessError('You may not delete '
          || api.pkg_ObjectQuery.GetTitle(a_ObjectId)
          || ' because addresses use it.');
    end if;

  end;

end pkg_AddressProcedures;

/
