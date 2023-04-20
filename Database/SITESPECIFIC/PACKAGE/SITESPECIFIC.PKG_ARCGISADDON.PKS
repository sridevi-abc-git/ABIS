CREATE OR REPLACE package SITESPECIFIC.pkg_ArcGisAddOn as

  subtype udt_Id is api.pkg_Definition.udt_Id;
  subtype udt_IdList is api.pkg_Definition.udt_IdList;
  subtype udt_Name is api.pkg_Definition.udt_Name;
  subtype udt_StringList is api.pkg_Definition.udt_StringList;

  /*---------------------------------------------------------------------------
   * GetDisplayInfo() -- PUBLIC
   *   Return map display info for a given object id.
   *-------------------------------------------------------------------------*/
  function GetDisplayInfo (
    a_ObjectId                          udt_Id
  ) return clob;

  /*---------------------------------------------------------------------------
   * GetLocationData() -- PUBLIC
   *   Return location data from the database for a given list of ObjectIds for
   * a given Add-On Configuration.
   *-------------------------------------------------------------------------*/
  function GetLocationData (
    a_AddOnConfigName                   varchar2,
    a_ObjectIds                         udt_IdList,
    a_ComponentTypeNames                udt_StringList
  ) return clob;

  /*---------------------------------------------------------------------------
   * GetMapConfig() -- PUBLIC
   *   Return map configuration for a given config name.
   *-------------------------------------------------------------------------*/
  function GetMapConfig (
    a_ConfigName                        varchar2
  ) return clob;

  /*---------------------------------------------------------------------------
   * GetObjectId() -- PUBLIC
   *   Return the ObjectId for a given map feature's data value.
   *-------------------------------------------------------------------------*/
  function GetObjectId (
    a_MapValue                          varchar2,
    a_FieldName                         varchar2,
    a_ComponentTypeName                 udt_Name
  ) return varchar2;

  /*---------------------------------------------------------------------------
   * GetObjectIdsForMapValues() -- PUBLIC
   *   Return a list of comma seperated POSSE ObjectIds matching the specified
   * map values.
   *-------------------------------------------------------------------------*/
  function GetObjectIdsForMapValues (
    a_MapValues                         udt_StringList,
    a_FieldName                         varchar2,
    a_ComponentTypeName                 udt_Name
  ) return udt_StringList;


  /*---------------------------------------------------------------------------
   * GetObjectsInRectangle() -- PUBLIC
   *   Return a JSON string containing the geometryType, objectId, x, and y for
   * all objects of a type on a map layer within an extent.
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
  ) return clob;

  /*---------------------------------------------------------------------------
   * ValidateDataSourceLayer() -- PUBLIC
   *   Ensure that o_MapDataSourceLayer.Name is unique within the related
   * o_MapDataSource object.
   *-------------------------------------------------------------------------*/
  procedure ValidateDataSourceLayer (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date,
    a_DataSourceObjectId                udt_Id,
    a_Name                              varchar2
  );

end pkg_ArcGisAddOn;
/
