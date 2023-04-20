CREATE OR REPLACE package body SITESPECIFIC.pkg_ArcGisAddOn as

  subtype udt_Boolean is api.pkg_Definition.udt_Boolean;
  subtype udt_SearchResults is api.pkg_Definition.udt_SearchResults;

  -- ObjectId list indexed by ComponentTypeName.
  type udt_ObjectListByName is table of udt_IdList index by udt_Name;

  /*---------------------------------------------------------------------------
   * AddOnList() -- PRIVATE
   *   Update a udt_ObjectListByName from lists of ObjectIds and Component Type
   * names.
   *-------------------------------------------------------------------------*/
  procedure AddOnList (
    a_ObjectIds                         udt_IdList,
    a_ComponentTypeNames                udt_StringList,
    a_ResultList                 in out udt_ObjectListByName
  ) is
    t_ComponentTypeName                 udt_Name;
    t_ObjectIds                         udt_IdList;
  begin

    for i in 1..a_ObjectIds.count() loop
      t_ComponentTypeName := a_ComponentTypeNames(i);
      if a_ResultList.exists(t_ComponentTypeName) then
        t_ObjectIds := a_ResultList(t_ComponentTypeName);
        t_ObjectIds(t_ObjectIds.count() + 1) := a_ObjectIds(i);
      else
        t_ObjectIds.delete();
        t_ObjectIds(1) := a_ObjectIds(i);
      end if;
      a_ResultList(t_ComponentTypeName) := t_ObjectIds;
    end loop;

  end;

  /*---------------------------------------------------------------------------
   * AppendToClob() -- PRIVATE
   *   Append the string to the CLOB.
   *-------------------------------------------------------------------------*/
  procedure AppendToClob (
    a_Clob                       in out clob,
    a_String                            varchar2
  ) is
  begin

    dbms_lob.writeappend(a_Clob, length(a_String), a_String);

  end;

  /*---------------------------------------------------------------------------
   * GeoCodingString() -- PRIVATE
   *   Return a cleaned-up geo-coding string.
   *-------------------------------------------------------------------------*/
  function GeoCodingString (
    a_String                            varchar2
  ) return varchar2 is
  begin

    if a_String is null then
      return 'null';
    else
      return trim(
          replace(
              replace(
                  replace(a_String, ',', ' '),
                  chr(13), ' '),
              chr(10), ' ')
          );
    end if;

  end;

  /*---------------------------------------------------------------------------
   * GeometryTypeString() -- PRIVATE
   *   Return the JavaScript value of Geometry Type, given the POSSE value.
   *-------------------------------------------------------------------------*/
  function GeometryTypeString (
    a_GeometryType                      varchar2
  ) return varchar2 is
  begin

    if a_GeometryType is null then
      return 'query';
    end if;

    case lower(a_GeometryType)
      when 'query'then
        return 'query';
      when 'x/y' then
        return 'xy';
      when 'lat/long' then
        return 'latlong';
      when 'address' then
        return 'address';
      else
        raise_application_error(-20000,
            'Unhandled Geometry Type: ''' || a_GeometryType || '''.');
    end case;

  end;

  /*---------------------------------------------------------------------------
   * JSONBoolean() -- PRIVATE
   *   Return the Boolean JSON for a string containing a POSSE boolean.
   *-------------------------------------------------------------------------*/
  function JSONBoolean (
    a_String                            varchar2
  ) return varchar2 is
  begin

    if a_String = 'Y' then
      return 'true';
    elsif a_String = 'N' then
      return 'false';
    else
      return 'null';
    end if;

  end;

  /*---------------------------------------------------------------------------
   * JSONString() -- PRIVATE
   *   Return a properly escaped string for JSON.
   *-------------------------------------------------------------------------*/
  function JSONString (
    a_String                            varchar2,
    a_StripLineBreaks                   boolean := true
  ) return varchar2 is
  begin

    if a_String is null then
      return 'null';
    elsif a_StripLineBreaks = false then
      return '"'
          || replace(
              replace(
                  replace(a_String, '"', '\"'),
                  chr(13), '\r'),
              chr(10), '\n')
          || '"';
    else
      return '"'
          || replace(
              replace(
                  replace( a_String, '"', '\"'),
                  chr(13), ' '),
              chr(10), ' ')
          || '"';
    end if;

  end;

  /*---------------------------------------------------------------------------
   * RemoveLastCharacter() -- PRIVATE
   *   If the last character in the CLOB is the indicated one, remove it.
   *-------------------------------------------------------------------------*/
  procedure RemoveLastCharacter (
    a_Clob                       in out clob,
    a_Character                         char
  ) is
    t_1                                 pls_integer := 1;
    t_Char                              char(1);
  begin

    dbms_lob.read(a_Clob, t_1, dbms_lob.getlength(a_Clob), t_Char);
    if t_Char = a_Character then
      dbms_lob.erase(a_Clob, t_1, dbms_lob.getlength(a_Clob));
    end if;

  end;

  /*---------------------------------------------------------------------------
   * SymbolId() -- PRIVATE
   *   Get the ArcGIS SymbolId for a given POSSE Symbol.  This is done by
   * compressing out spaces.
   *-------------------------------------------------------------------------*/
  function SymbolId (
    a_Symbol                            varchar2
  ) return varchar2 is
  begin

    return replace(a_Symbol, ' ', '');

  end;

  /*---------------------------------------------------------------------------
   * TranslationObjectId() -- PRIVATE
   *   Get the ObjectId of the MapLayerTranslation object for the add-on config
   * and component type.
   *-------------------------------------------------------------------------*/
  function TranslationObjectId (
    a_AddOnConfigName                   varchar2,
    a_DataSourceId                      varchar2,
    a_ComponentTypeName                 udt_Name
  ) return udt_Id is
    t_ObjectId                          udt_Id;
    t_ObjectIdByTranslationOrder        udt_IdList;
    t_SearchResults                     udt_SearchResults;
    t_TranslationOrder                  number;
  begin

    t_SearchResults := api.pkg_Search.NewSearchResults();
    if not api.pkg_Search.IntersectByColumnValue('o_MapLayerTranslation',
        'ComponentTypeName', a_ComponentTypeName, t_SearchResults) then
      raise_application_error(-20000,
          'Could not find translation for component type named '''
          || a_ComponentTypeName || '''.');
    end if;

    if a_DataSourceId is not null then
      if not api.pkg_Search.IntersectByRelColumnValue(
          'o_MapLayerTranslation', 'MapDataSource', 'DataSourceId',
          a_DataSourceId, t_SearchResults) then
        raise_application_error(-20000,
            'Could not find translation for component type named '''
            || a_ComponentTypeName || ''' with data source '''
            || a_DataSourceId || '''.');
      end if;
    end if;

    if not api.pkg_Search.IntersectByRelColumnValue('o_MapLayerTranslation',
        'MapConfiguration', 'AddOnConfigName', a_AddOnConfigName,
        t_SearchResults) then
      if a_DataSourceId is null then
        raise_application_error(-20000,
            'Could not find translation for component type named '''
            || a_ComponentTypeName || ''' in AddOn Config '''
            || a_AddOnConfigName || '''.');
      else
        raise_application_error(-20000,
            'Could not find translation for component type named '''
            || a_ComponentTypeName || ''' with data source '''
            || a_DataSourceId || ''' in AddOn Config '''
            || a_AddOnConfigName || '''.');
      end if;
    end if;

    -- If there are multiple translation objects, we take the one with the
    -- lowest TranslationOrder.  To do this, use a udt_IdList as a sparse array
    -- indexed by TranslationOrder.
    t_ObjectId := t_SearchResults.ObjectIdSparseArray.first();
    while t_ObjectId is not null loop
      t_TranslationOrder := api.pkg_ColumnQuery.NumericValue(t_ObjectId,
          'TranslationOrder');
      t_ObjectIdByTranslationOrder(t_TranslationOrder) := t_ObjectId;

      t_ObjectId := t_SearchResults.ObjectIdSparseArray.next(t_ObjectId);
    end loop;

    -- Get the lowest numbered one.
    return t_ObjectIdByTranslationOrder(t_ObjectIdByTranslationOrder.first());

  end;

  /*---------------------------------------------------------------------------
   * GetLocationData() -- PUBLIC
   *-------------------------------------------------------------------------*/
  function GetLocationData (
    a_AddOnConfigName                   varchar2,
    a_ObjectIds                         udt_IdList,
    a_ComponentTypeNames                udt_StringList
  ) return clob is
    t_ComponentTypeName                 udt_Name;
    t_DataSource                        varchar2(4000);
    t_DataValue                         varchar2(4000);
    t_EndPointId                        udt_Id;
    t_EndPointName                      udt_Name;
    t_GeometryType                      varchar2(8);
    t_LayerName                         varchar2(4000);
    t_ObjectIdsByComponentTypeName      udt_ObjectListByName;
    t_ObjectId                          udt_Id;
    t_ObjectIds                         udt_IdList;
    t_PropertyName                      varchar2(4000);
    t_QueryAction                       varchar2(100);
    t_RelatedObjects                    udt_IdList;
    t_ReturnValue                       clob;
    t_SearchResults                     udt_SearchResults;
    t_TranslationObjectId               udt_Id;
    t_ShowRelatedWithPin                udt_Boolean;
    t_ValueFieldName                    udt_Name;
    t_ValueFound                        boolean;
  begin

    t_ReturnValue := '[';
    AddOnList(a_ObjectIds, a_ComponentTypeNames,
        t_ObjectIdsByComponentTypeName);

    t_ComponentTypeName := t_ObjectIdsByComponentTypeName.first();
    while t_ComponentTypeName is not null loop
      t_TranslationObjectId := TranslationObjectId(a_AddOnConfigName, null,
          t_ComponentTypeName);
      t_EndPointName := api.pkg_ColumnQuery.Value(t_TranslationObjectId,
          'EndPointName');
      t_ValueFieldName := api.pkg_ColumnQuery.Value(t_TranslationObjectId,
          'ValueField');

      t_GeometryType := GeometryTypeString(api.pkg_ColumnQuery.Value(
          t_TranslationObjectId, 'GeometryType'));
      t_PropertyName := trim(api.pkg_ColumnQuery.Value(t_TranslationObjectId,
          'PropertyName'));
      if t_PropertyName is null then
        t_PropertyName := trim(api.pkg_ColumnQuery.Value(t_TranslationObjectId,
            'DefaultPropertyName'));
      end if;

      t_DataSource := api.pkg_ColumnQuery.Value(t_TranslationObjectId,
          'DataSourceId');
      t_LayerName := api.pkg_ColumnQuery.Value(t_TranslationObjectId,
          'LayerName');
      t_ShowRelatedWithPin := api.pkg_ColumnQuery.Value(t_TranslationObjectId,
          'ShowRelatedWithPin');

      t_ObjectIds := t_ObjectIdsByComponentTypeName(t_ComponentTypeName);
      for i in 1..t_ObjectIds.count() loop
        t_ObjectId := t_ObjectIds(i);

        if t_EndPointName is null then
          t_DataValue := api.pkg_ColumnQuery.Value(t_ObjectId,
              t_ValueFieldName);
          if GeoCodingString(t_DataValue) is null then
            AppendToClob(t_ReturnValue, '{error:'
                || JSONString('Could not find value for object with id '''
                    || t_ObjectId || '''.')
                || '},');
          else
            AppendToClob(t_ReturnValue, '{');
            AppendToClob(t_ReturnValue, 'componentTypeName:'
                || JSONString(t_ComponentTypeName) || ',');
            AppendToClob(t_ReturnValue, 'geometryType:'
                || JSONString(t_GeometryType) || ',');
            AppendToClob(t_ReturnValue, 'objectId:'
                || t_ObjectId || ',');
            if t_GeometryType = 'address' then
              AppendToClob(t_ReturnValue, 'streetAddress:'
                  || JSONString(trim(t_DataValue)) || ',');
            else
              AppendToClob(t_ReturnValue, 'values:'
                  || JSONString(t_DataValue) || ',');
            end if;

            AppendToClob(t_ReturnValue, 'layerName:'
                || JSONString(t_LayerName) || ',');
            AppendToClob(t_ReturnValue, 'dataSourceId:'
                || JSONString(t_DataSource) || ',');

            if t_GeometryType = 'query' then
              AppendToClob(t_ReturnValue, 'propertyName:'
                  || JSONString(t_PropertyName) || ',');
              AppendToClob(t_ReturnValue, 'action:"select",');
            else
              AppendToClob(t_ReturnValue, 'action:null,');
            end if;

            RemoveLastCharacter(t_ReturnValue, ',');
            AppendToClob(t_ReturnValue, '},');
          end if;
        else -- Traverse relationship
          t_EndPointId := api.pkg_ConfigQuery.EndPointIdForName(
              t_ComponentTypeName, t_EndPointName);
          t_RelatedObjects := api.pkg_ObjectQuery.RelatedObjects(t_ObjectId,
              t_EndPointId);
          -- There could be multiple related values, in which case we want to
          -- return all of them.
          t_ValueFound := false;
          for o in 1..t_RelatedObjects.count() loop
            t_DataValue := api.pkg_ColumnQuery.Value(t_RelatedObjects(o),
                t_ValueFieldName);
            if t_DataValue is null or GeoCodingString(t_DataValue) is null then
              continue;
            end if;

            t_ValueFound := true;

            -- Override the query action with select if specified in config
            if t_GeometryType = 'query'
                and t_ShowRelatedWithPin = 'N' then
              t_QueryAction := 'select';
            else
              --Use default functionality, which is "addFeatureAsPoint"
              t_QueryAction := null;
            end if;

            AppendToClob(t_ReturnValue, '{');
            AppendToClob(t_ReturnValue, 'geometryType:'
                || JSONString(t_GeometryType) || ',');
            AppendToClob(t_ReturnValue, 'objectId:'
                || t_ObjectId || ',');
            AppendToClob(t_ReturnValue, 'action:'
                || JSONString(t_QueryAction) || ',');
            AppendToClob(t_ReturnValue, 'dataSourceId:'
                || JSONString(t_DataSource) || ',');
            AppendToClob(t_ReturnValue, 'layerName:'
                || JSONString(t_LayerName) || ',');

            if t_GeometryType = 'address' then
              AppendToClob(t_ReturnValue, 'streetAddress:'
                  || JSONString(trim(t_DataValue)) || ',');
            else
              AppendToClob(t_ReturnValue, 'values:'
                  || JSONString(t_DataValue) || ',');
            end if;
            if t_GeometryType = 'query' then
              AppendToClob(t_ReturnValue, 'propertyName:'
                  || JSONString(t_PropertyName) || ',');
            end if;

            RemoveLastCharacter(t_ReturnValue, ',');
            AppendToClob(t_ReturnValue, '},');
          end loop;

          if not t_ValueFound then
            AppendToClob(t_ReturnValue, '{error:'
                || JSONString('Could not find value for object with id '''
                    || t_ObjectId || '''.')
                || '},');
          end if;
        end if;
      end loop;

      t_ComponentTypeName := t_ObjectIdsByComponentTypeName.next(
          t_ComponentTypeName);
    end loop;

    RemoveLastCharacter(t_ReturnValue, ',');
    AppendToClob(t_ReturnValue, ']');

    return t_ReturnValue;

  end;

  /*---------------------------------------------------------------------------
   * GetMapConfig() -- PUBLIC
   *-------------------------------------------------------------------------*/
  function GetMapConfig (
    a_ConfigName                        varchar2
  ) return clob is
    t_ReturnValue                       clob;
  begin

    t_ReturnValue := '{';

    for c in (
        select
          ObjectId,
          MapTitle,
          GeometryServiceURL,
          LocatorServiceURL,
          InitialCentroidX,
          InitialCentroidY,
          MapSpatialReferenceWKID,
          DefaultScale,
          FullExtent,
          MeasureUnits,
          SaveMapAction,
          SaveMapExtent,
          SaveVisibleLayers,
          NetworkAnalysisServiceURL,
          RouteUnits,
          RouteFindBestSequence,
          RoutePreserveFirstStop,
          RoutePreserveLastStop,
          PrintServiceURL,
          PrintFormat,
          MapIsUsedForCriteria,
          MapIsUsedForEditing,
          MapIsUsedForRelatingObjects,
          EnableSelectTools,
          EnableLocateTool,
          EnableBufferTool,
          EnableMeasureTool,
          EnableLegend,
          EnableNewPointTool,
          EnableNewLineTool,
          EnableNewPolygonTool,
          EnableNewFeatureFromSelection,
          EnableNewPointFromAddressTool,
          EnableEditFeatureTool,
          EnableDeleteFeatureTool,
          AutoSelectBufferedFeatures
        from query.o_MapConfiguration
        where ObjectId = api.pkg_Search.ObjectByColumnValue(
            'o_MapConfiguration', 'AddOnConfigName', a_ConfigName)
        ) loop
      AppendToClob(t_ReturnValue, 'name:'
          || JSONString(c.MapTitle) || ',');
      AppendToClob(t_ReturnValue, 'geometryServiceUrl:'
          || JSONString(c.GeometryServiceURL) || ',');
      AppendToClob(t_ReturnValue, 'locatorServiceUrl:'
          || JSONString(c.LocatorServiceURL) || ',');
      AppendToClob(t_ReturnValue, 'initialCentroid:{x:'
          || c.InitialCentroidX || ',y:' || c.InitialCentroidY
          || ',spatialReference:{wkid:' || c.MapSpatialReferenceWKID || '}},');
      AppendToClob(t_ReturnValue, 'fullExtent:'
          || c.FullExtent || ',');
      AppendToClob(t_ReturnValue, 'defaultScale:'
          || c.DefaultScale || ',');
      AppendToClob(t_ReturnValue, 'measureUnits:'
          || JSONString(c.MeasureUnits) || ',');
      AppendToClob(t_ReturnValue, 'autoSelectBufferedFeatures:'
          || JSONBoolean(c.AutoSelectBufferedFeatures) || ',');
      AppendToClob(t_ReturnValue, 'saveMapAction:'
          || JSONBoolean(c.SaveMapAction) || ',');
      AppendToClob(t_ReturnValue, 'saveMapExtent:'
          || JSONBoolean(c.SaveMapExtent) || ',');
      AppendToClob(t_ReturnValue, 'saveMapVisibleLayers:'
          || JSONBoolean(c.SaveVisibleLayers) || ',');
      AppendToClob(t_ReturnValue, 'networkAnalysisServiceUrl:'
          || JSONString(c.NetworkAnalysisServiceURL) || ',');
      AppendToClob(t_ReturnValue, 'routeUnits:'
          || JSONString(c.RouteUnits) || ',');
      AppendToClob(t_ReturnValue, 'routeFindBestSequence:'
          || JSONBoolean(c.RouteFindBestSequence) || ',');
      AppendToClob(t_ReturnValue, 'routePreserveFirstStop:'
          || JSONBoolean(c.RoutePreserveFirstStop) || ',');
      AppendToClob(t_ReturnValue, 'routePreserveLastStop:'
          || JSONBoolean(c.RoutePreserveLastStop) || ',');
      AppendToClob(t_ReturnValue, 'printServiceUrl:'
          || JSONString(c.PrintServiceURL) || ',');
      AppendToClob(t_ReturnValue, 'printFormat:'
          || JSONString(c.PrintFormat) || ',');
      AppendToClob(t_ReturnValue, 'isCriteriaMap:'
          || JSONBoolean(c.MapIsUsedForCriteria) || ',');
      AppendToClob(t_ReturnValue, 'isEditMap:'
          || JSONBoolean(c.MapIsUsedForEditing) || ',');
      AppendToClob(t_ReturnValue, 'isRelateMap:'
          || JSONBoolean(c.MapIsUsedForRelatingObjects) || ',');
      AppendToClob(t_ReturnValue, 'enableSelect:'
          || JSONBoolean(c.EnableSelectTools) || ',');
      AppendToClob(t_ReturnValue, 'enableLocate:'
          || JSONBoolean(c.EnableLocateTool) || ',');
      AppendToClob(t_ReturnValue, 'enableBuffer:'
          || JSONBoolean(c.EnableBufferTool) || ',');
      AppendToClob(t_ReturnValue, 'enableMeasure:'
          || JSONBoolean(c.EnableMeasureTool) || ',');
      AppendToClob(t_ReturnValue, 'enableLegend:'
          || JSONBoolean(c.EnableLegend) || ',');
      AppendToClob(t_ReturnValue, 'enableNewPoint:'
          || JSONBoolean(c.EnableNewPointTool) || ',');
      AppendToClob(t_ReturnValue, 'enableNewLine:'
          || JSONBoolean(c.EnableNewLineTool) || ',');
      AppendToClob(t_ReturnValue, 'enableNewPolygon:'
          || JSONBoolean(c.EnableNewPolygonTool) || ',');
      AppendToClob(t_ReturnValue, 'enableNewFeatureFromSelection:'
          || JSONBoolean(c.EnableNewFeatureFromSelection) || ',');
      AppendToClob(t_ReturnValue, 'enableNewPointFromAddress:'
          || JSONBoolean(c.EnableNewPointFromAddressTool) || ',');
      AppendToClob(t_ReturnValue, 'enableEditFeature:'
          || JSONBoolean(c.EnableEditFeatureTool) || ',');
      AppendToClob(t_ReturnValue, 'enableDeleteFeature:'
          || JSONBoolean(c.EnableDeleteFeatureTool) || ',');

      AppendToClob(t_ReturnValue, 'dataSources:[');
      for d in (
          select
            ds.ObjectId,
            ds.DataSourceId,
            ds.Type,
            ds.Name,
            ds.ServiceURL,
            ds.Opacity,
            ds.ShowInLegend
          from
            query.r_MapConfigurationToDataSource r
            join query.o_MapDataSource ds
                on ds.ObjectId = r.DataSourceObjectId
          where r.MapConfigObjectId = c.ObjectId
          order by
            r.OrderNumber,
            lower(ds.Name)
          ) loop
        AppendToClob(t_ReturnValue, '{');
        case d.Type
          when 'ArcGIS' then
            AppendToClob(t_ReturnValue, 'id:'
                || JSONString(d.DataSourceId) || ',');
            AppendToClob(t_ReturnValue, 'type:'
                || JSONString(lower(d.Type)) || ',');
            AppendToClob(t_ReturnValue, 'name:'
                || JSONString(d.Name) || ',');
            AppendToClob(t_ReturnValue, 'serviceUrl:'
                || JSONString(d.ServiceUrl) || ',');
            AppendToClob(t_ReturnValue, 'opacity:'
                || JSONString(d.Opacity) || ',');

            AppendToClob(t_ReturnValue, 'layers:[');
            for l in (
                select
                  dsl.ObjectId,
                  dsl.Name,
                  dsl.Label,
                  dsl.Selectable,
                  dsl.Identifiable,
                  dsl.Visible,
                  dsl.ShowInLegend,
                  dsl.MaximumScale,
                  dsl.Opacity,
                  dsl.DefaultPropertyName,
                  dsl.LayerIdentifierName
                from
                  query.r_MapDataSourceToLayer r
                  join query.o_MapDataSourceLayer dsl
                      on dsl.ObjectId = r.LayerObjectId
                where r.DataSourceObjectId = d.ObjectId
                order by dsl.LayerOrder
                ) loop
              AppendToClob(t_ReturnValue, '{');
              AppendToClob(t_ReturnValue, 'name:'
                  || JSONString(l.Name) || ',');
              AppendToClob(t_ReturnValue, 'label:'
                  || JSONString(l.Label) || ',');
              AppendToClob(t_ReturnValue, 'selectable:'
                  || JSONBoolean(l.Selectable) || ',');
              AppendToClob(t_ReturnValue, 'identifiable:'
                  || JSONBoolean(l.Identifiable) || ',');
              AppendToClob(t_ReturnValue, 'visible:'
                  || JSONBoolean(l.Visible) || ',');
              if l.MaximumScale is null then
                AppendToClob(t_ReturnValue, 'maximumScale:null,');
              else
                AppendToClob(t_ReturnValue, 'maximumScale:'
                    || l.MaximumScale || ',');
              end if;
              AppendToClob(t_ReturnValue, 'selectedFeatureIdName:'
                  || JSONString(l.LayerIdentifierName) || ',');

              AppendToClob(t_ReturnValue, 'translations: [');
              for t in (
                  select
                    lt.ObjectId,
                    lt.ComponentTypeName,
                    lt.ValueField,
                    lt.PropertyName,
                    lt.EndPointName,
                    lt.GeometryType
                  from
                    query.r_MapLayerToTranslation r
                    join query.o_MapLayerTranslation lt
                        on lt.ObjectId = r.TranslationObjectId
                  where r.LayerObjectId = l.ObjectId
                  ) loop
                AppendToClob(t_ReturnValue, '{');
                AppendToClob(t_ReturnValue, 'componentType:'
                    || JSONString(t.ComponentTypeName) || ',');
                AppendToClob(t_ReturnValue, 'geometryType:'
                    || JSONString(GeometryTypeString(t.GeometryType)) || ',');
                AppendToClob(t_ReturnValue, 'valueField:'
                    || JSONString(t.ValueField) || ',');
                if trim(t.PropertyName) is not null then
                  AppendToClob(t_ReturnValue, 'propertyName:'
                      || JSONString(t.PropertyName) || ',');
                else
                  AppendToClob(t_ReturnValue, 'propertyName:'
                      || JSONString(l.DefaultPropertyName) || ',');
                end if;
                AppendToClob(t_ReturnValue, 'endPointName:'
                    || JSONString(t.EndPointName));
                AppendToClob(t_ReturnValue, '},');
              end loop;
              RemoveLastCharacter(t_ReturnValue, ',');
              AppendToClob(t_ReturnValue, ']');
              AppendToClob(t_ReturnValue, '},');
            end loop;
            RemoveLastCharacter(t_ReturnValue, ',');
            AppendToClob(t_ReturnValue, ']');

          else
            AppendToClob(t_ReturnValue, 'id:'
                || JSONString(d.DataSourceId) || ',');
            AppendToClob(t_ReturnValue, 'type:'
                || JSONString(lower(d.Type)) || ',');
            AppendToClob(t_ReturnValue, 'name:'
                || JSONString(d.Name) || ',');
            AppendToClob(t_ReturnValue, 'serviceUrl:'
                || JSONString(d.ServiceUrl) || ',');
            AppendToClob(t_ReturnValue, 'opacity:'
                || JSONString(d.Opacity) || ',');
            AppendToClob(t_ReturnValue, 'showInLegend:'
                || JSONBoolean(d.ShowInLegend) || ',');

            AppendToClob(t_ReturnValue, 'layers:[');
            for l in (
                select
                  dsl.ObjectId,
                  dsl.Name,
                  dsl.Label,
                  dsl.Selectable,
                  dsl.Identifiable,
                  dsl.Visible,
                  dsl.Editable,
                  dsl.ShowInLegend,
                  dsl.MaximumScale,
                  dsl.Opacity,
                  dsl.Symbol,
                  dsl.DefaultPropertyName,
                  dsl.LayerIdentifierName
                from
                  query.r_MapDataSourceToLayer r
                  join query.o_MapDataSourceLayer dsl
                      on dsl.ObjectId = r.LayerObjectId
                where r.DataSourceObjectId = d.ObjectId
                order by dsl.LayerOrder
                ) loop
              AppendToClob(t_ReturnValue, '{');
              AppendToClob(t_ReturnValue, 'name:'
                  || JSONString(l.Name) || ',');
              AppendToClob(t_ReturnValue, 'label:'
                  || JSONString(l.Label) || ',');
              AppendToClob(t_ReturnValue, 'selectable:'
                  || JSONBoolean(l.Selectable) || ',');
              AppendToClob(t_ReturnValue, 'visible:'
                  || JSONBoolean(l.Visible) || ',');
              AppendToClob(t_ReturnValue, 'editable:'
                  || JSONBoolean(l.Editable) || ',');
              AppendToClob(t_ReturnValue, 'showInLegend:'
                  || JSONBoolean(l.ShowInLegend) || ',');
              AppendToClob(t_ReturnValue, 'maximumScale:'
                  || l.MaximumScale || ',');
              AppendToClob(t_ReturnValue, 'opacity:'
                  || JSONString(l.Opacity) || ',');
              AppendToClob(t_ReturnValue, 'symbolId:'
                  || JSONString(SymbolId(l.Symbol)) || ',');
              AppendToClob(t_ReturnValue, 'selectedFeatureIdName:'
                  || JSONString(l.LayerIdentifierName) || ',');

              AppendToClob(t_ReturnValue, 'translations: [');
              for t in (
                  select
                    lt.ObjectId,
                    lt.ComponentTypeName,
                    lt.ValueField,
                    lt.PropertyName,
                    lt.EndPointName,
                    lt.GeometryType
                  from
                    query.r_MapLayerToTranslation r
                    join query.o_MapLayerTranslation lt
                        on lt.ObjectId = r.TranslationObjectId
                  where r.LayerObjectId = l.ObjectId
                  order by lt.TranslationOrder
                  ) loop
                AppendToClob(t_ReturnValue, '{');
                AppendToClob(t_ReturnValue, 'componentType:'
                    || JSONString(t.ComponentTypeName) || ',');
                AppendToClob(t_ReturnValue, 'geometryType:'
                    || JSONString(GeometryTypeString(t.GeometryType)) || ',');
                AppendToClob(t_ReturnValue, 'valueField:'
                    || JSONString(t.ValueField) || ',');
                if trim(t.PropertyName) is not null then
                  AppendToClob(t_ReturnValue, 'propertyName:'
                      || JSONString(t.PropertyName) || ',');
                else
                  AppendToClob(t_ReturnValue, 'propertyName:'
                      || JSONString(l.DefaultPropertyName) || ',');
                end if;
                AppendToClob(t_ReturnValue, 'endPointName:'
                    || JSONString(t.EndPointName));
                AppendToClob(t_ReturnValue, '},');
              end loop;
              RemoveLastCharacter(t_ReturnValue, ',');
              AppendToClob(t_ReturnValue, ']');
              AppendToClob(t_ReturnValue, '},');
            end loop;
            RemoveLastCharacter(t_ReturnValue, ',');
            AppendToClob(t_ReturnValue, ']');
        end case;
        AppendToClob(t_ReturnValue, '},');
      end loop;
      RemoveLastCharacter(t_ReturnValue, ',');
      AppendToClob(t_ReturnValue, ']');
    end loop;
    AppendToClob(t_ReturnValue, '}');

    return t_ReturnValue;

  end;

  /*---------------------------------------------------------------------------
   * GetDisplayInfo() -- PUBLIC
   *-------------------------------------------------------------------------*/
  function GetDisplayInfo (
    a_ObjectId                          udt_Id
  ) return clob is
    t_ReturnValue                       clob;
  begin

    t_ReturnValue := '{';
    AppendToClob(t_ReturnValue, 'displayFormat:' || JSONString(
        api.pkg_ColumnQuery.Value(a_ObjectId, 'DisplayFormat'), false) || ',');
    AppendToClob(t_ReturnValue, 'title:' || JSONString(
        api.pkg_ColumnQuery.Value(a_ObjectId, 'ObjectDefDescription')));
    AppendToClob(t_ReturnValue, '}');

    return t_ReturnValue;

  end GetDisplayInfo;

  /*---------------------------------------------------------------------------
   * GetObjectId() -- PUBLIC
   *-------------------------------------------------------------------------*/
  function GetObjectId (
    a_MapValue                          varchar2,
    a_FieldName                         varchar2,
    a_ComponentTypeName                 udt_Name
  ) return varchar2 is
    t_DataType                          udt_Name;
    t_ObjectDefId                       udt_Id;
    t_ObjectId                          udt_Id;
  begin

    t_ObjectDefId := api.pkg_ConfigQuery.ObjectDefIdForName(a_ComponentTypeName);

    select DataType
    into t_DataType
    from api.ColumnDefs
    where ObjectDefId = t_ObjectDefId
      and lower(Name) = lower(a_FieldName);

    case t_DataType
      when 'date' then
        t_ObjectId := api.pkg_Search.ObjectByColumnValue(
            a_ComponentTypeName, a_FieldName,
            to_date(a_MapValue, 'yyyy-mm-dd hh24:mi:ss'));
      when 'number' then
        t_ObjectId := api.pkg_Search.ObjectByColumnValue(
            a_ComponentTypeName, a_FieldName, to_number(a_MapValue));
      else
        t_ObjectId := api.pkg_Search.ObjectByColumnValue(
            a_ComponentTypeName, a_FieldName, a_MapValue);
    end case;

    if t_ObjectId is null then
      return '{error:''No ObjectId found for field (' || a_FieldName
          || ') and value (' || a_MapValue || ').''}';
    else
      return '{objectId:' || t_ObjectId || '}';
    end if;

  end;

  /*---------------------------------------------------------------------------
   * GetObjectIdsForMapValues() -- PUBLIC
   *-------------------------------------------------------------------------*/
  function GetObjectIdsForMapValues (
    a_MapValues                         udt_StringList,
    a_FieldName                         varchar2,
    a_ComponentTypeName                 udt_Name
  ) return udt_StringList is
    t_DataType                          udt_Name;
    t_ObjectDefId                       udt_Id;
    t_ObjectIds                         udt_StringList;
    t_ObjectIdsForValue                 udt_IdList;
    t_ObjectIdsString                   varchar2(4000);
  begin

    t_ObjectDefId := api.pkg_ConfigQuery.ObjectDefIdForName(a_ComponentTypeName);

    select DataType
    into t_DataType
    from api.ColumnDefs
    where ObjectDefId = t_ObjectDefId
      and lower(Name) = lower(a_FieldName);

    for i in 1..a_MapValues.count() loop
      case t_DataType
        when 'date' then
          t_ObjectIdsForValue := api.pkg_Search.ObjectsByColumnValue(
              a_ComponentTypeName, a_FieldName,
              to_date(a_MapValues(i), 'yyyy-mm-dd hh24:mi:ss'));
        when 'number' then
          t_ObjectIdsForValue := api.pkg_Search.ObjectsByColumnValue(
              a_ComponentTypeName, a_FieldName, to_number(a_MapValues(i)));
        else
          t_ObjectIdsForValue := api.pkg_Search.ObjectsByColumnValue(
              a_ComponentTypeName, a_FieldName, a_MapValues(i));
      end case;
      t_ObjectIdsString := '';
      for j in 1..t_ObjectIdsForValue.count() loop
        if t_ObjectIdsString is not null then
          t_ObjectIdsString := t_ObjectIdsString || ',';
        end if;
        t_ObjectIdsString := t_ObjectIdsString || t_ObjectIdsForValue(j);
      end loop;
      t_ObjectIds(t_ObjectIds.count() + 1) := t_ObjectIdsString;
    end loop;

    return t_ObjectIds;

  end;

  /*---------------------------------------------------------------------------
   * GetObjectsInRectangle() -- PUBLIC
   *-------------------------------------------------------------------------*/
  function GetObjectsInRectangle (
    a_AddOnConfigName                   varchar2,
    a_DataSourceId                      varchar2,
    a_LayerName                         varchar2,
    a_ComponentTypeName                 udt_Name,
    a_ExtentMinX                        number,
    a_ExtentMinY                        number,
    a_ExtentMaxX                        number,
    a_ExtentMaxY                        number
  ) return clob is
    t_ComponentWithGeometry             udt_Name;
    t_EndPointId                        udt_Id;
    t_EndPointName                      udt_Name;
    t_GeometryType                      varchar2(8);
    t_ObjectDefId                       udt_Id;
    t_ObjectId                          udt_Id;
    t_ObjectIds                         udt_IdList;
    t_ReturnValue                       clob;
    t_SearchResults                     udt_SearchResults;
    t_TranslationObjectId               udt_Id;
    t_X                                 number;
    t_Y                                 number;
  begin

    t_TranslationObjectId := TranslationObjectId(a_AddOnConfigName,
        a_DataSourceId, a_ComponentTypeName);
    t_GeometryType := GeometryTypeString(api.pkg_ColumnQuery.Value(
        t_TranslationObjectid, 'GeometryType'));

    t_EndPointName := api.pkg_ColumnQuery.Value(t_TranslationObjectId,
        'EndPointName');
    if t_EndPointName is null then
      t_ComponentWithGeometry := a_ComponentTypeName;
    else
      -- The actual component with geometry is at the other end of the rel.
      t_ObjectDefId := api.pkg_ConfigQuery.ObjectDefIdForName(a_ComponentTypeName);

      select
        oe.EndPointId,
        tod.Name
      into
        t_EndPointId,
        t_ComponentWithGeometry
      from
        api.EndPoints e
        join api.ObjectDefs tod
            on tod.ObjectDefId = e.ToObjectDefId
        join api.EndPoints oe
            on oe.RelationshipDefId = e.RelationshipDefId
            and oe.EndPointId != e.EndPointId
      where e.FromObjectDefId = t_ObjectDefId;
    end if;

    t_ReturnValue := '[';

    t_SearchResults := api.pkg_Search.NewSearchResults();
    if not api.pkg_Search.IntersectByColumnValue(t_ComponentWithGeometry,
        'MapCoordinateX', a_ExtentMinX, a_ExtentMaxX, t_SearchResults) then
      -- The search didn't find anything. We're done.
      AppendToClob(t_ReturnValue, ']');

      return t_ReturnValue;
    end if;

    if not api.pkg_Search.IntersectByColumnValue(t_ComponentWithGeometry,
        'MapCoordinateY', a_ExtentMinY, a_ExtentMaxY, t_SearchResults) then
      -- The search didn't find anything. We're done.
      AppendToClob(t_ReturnValue, ']');
      return t_ReturnValue;
    end if;

    api.pkg_Search.WriteSearchResults(t_SearchResults);

    for o in (
        select ObjectId
        from api.SearchResults
        ) loop
      if t_EndPointId is null then
        AppendToClob(t_ReturnValue, '{');
        AppendToClob(t_ReturnValue, 'geometryType:'
            || JSONString(t_GeometryType) || ',');
        AppendToClob(t_ReturnValue, 'objectId:' || o.ObjectId || ',');
        AppendToClob(t_ReturnValue, 'x:'
            || api.pkg_ColumnQuery.Value(o.ObjectId, 'MapCoordinateX') || ',');
        AppendToClob(t_ReturnValue, 'y:'
            || api.pkg_ColumnQuery.Value(o.ObjectId, 'MapCoordinateY'));
        AppendToClob(t_ReturnValue, '},');
      else
        t_X := api.pkg_ColumnQuery.NumericValue(o.ObjectId, 'MapCoordinateX');
        t_Y := api.pkg_ColumnQuery.NumericValue(o.ObjectId, 'MapCoordinateY');

        t_ObjectIds := api.pkg_ObjectQuery.RelatedObjects(o.ObjectId,
            t_EndPointId);
        for i in 1..t_ObjectIds.count() loop
          t_ObjectId := t_ObjectIds(i);
          AppendToClob(t_ReturnValue, '{');
          AppendToClob(t_ReturnValue, 'geometryType:'
              || JSONString(t_GeometryType) || ',');
          AppendToClob(t_ReturnValue, 'objectId:' || t_ObjectId || ',');
          AppendToClob(t_ReturnValue, 'x:' || t_X || ',');
          AppendToClob(t_ReturnValue, 'y:' || t_Y);
          AppendToClob(t_ReturnValue, '},');
        end loop;
      end if;
    end loop;

    RemoveLastCharacter(t_ReturnValue, ',');
    AppendToClob(t_ReturnValue, ']');

    return t_ReturnValue;

  end;

  /*---------------------------------------------------------------------------
   * ValidateDataSourceLayer() -- PUBLIC
   *-------------------------------------------------------------------------*/
  procedure ValidateDataSourceLayer (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date,
    a_DataSourceObjectId                udt_Id,
    a_Name                              varchar2
  ) is
    t_Count                             pls_integer;
  begin

    select count(*)
    into t_Count
    from
      query.r_MapDataSourceToLayer dsl
      join query.o_MapDataSourceLayer l2
          on l2.ObjectId = dsl.LayerObjectId
          and lower(l2.Name) = lower(a_Name)
    where dsl.DataSourceObjectId = a_DataSourceObjectId
      and dsl.LayerObjectId != a_ObjectId;

    if t_Count > 0 then
      api.pkg_Errors.QueueBusinessError('There is already a Layer named "'
          || a_Name || '" on Data Source "'
          || api.pkg_ColumnQuery.Value(a_DataSourceObjectId, 'DataSourceId')
          || '".');
    end if;

  end;

end pkg_ArcGisAddOn;
/
