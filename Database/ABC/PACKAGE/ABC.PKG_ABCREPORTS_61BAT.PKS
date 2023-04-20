CREATE OR REPLACE package ABC.pkg_ABCReports_61BAT as
  /*---------------------------------------------------------------------------
  * Types
  *-------------------------------------------------------------------------*/
  subtype udt_Id is api.pkg_Definition.udt_Id;
  subtype udt_EndPoint is api.pkg_definition.udt_EndPoint;
  subtype udt_ObjectList is api.udt_ObjectList;

  procedure ABC61BatchMultiPrint(
    a_ObjectId udt_Id
  );

  procedure Populate61Batch (
    a_ObjectId udt_Id,
    a_TakenOn date,
    a_SupervisorAssignedOn date,
    a_CommentsDate date,
    a_ActiveOnly char,
    a_InvestigationType varchar2,
    a_Investigator varchar2,
    a_UserId udt_id,
    a_ObjectIds api.udt_objectlist
  );

  procedure Get61ENFBatch (
    a_ObjectId udt_Id,
    a_TakenOn date,
    a_SupervisorAssignedOn date,
    a_CommentsDate date,
    a_ActiveOnly char,
    a_InvestigationType varchar2,
    a_Investigator varchar2,
    a_UserId udt_id,
    a_ObjectIds api.udt_objectlist
  );

  procedure Get61LICBatch (
    a_ObjectId udt_Id,
    a_TakenOn date,
    a_SupervisorAssignedOn date,
    a_CommentsDate date,
    a_ActiveOnly char,
    a_InvestigationType varchar2,
    a_Investigator varchar2,
    a_UserId udt_id,
    a_ObjectIds api.udt_objectlist
  );

  procedure Get61LogBatch (
    a_ObjectId udt_Id,
    a_TakenOn date,
    a_SupervisorAssignedOn date,
    a_CommentsDate date,
    a_ActiveOnly char,
    a_InvestigationType varchar2,
    a_Investigator varchar2,
    a_UserId udt_id,
    a_ObjectIds api.udt_objectlist
  );

  function Get61ENFObjectList(
    a_TakenOn date,
    a_InvestigationType varchar2,
    a_Investigator varchar2
  ) return api.udt_ObjectList;

  function Get61LICObjectList(
    a_Investigator varchar2
  ) return api.udt_ObjectList;

end pkg_ABCReports_61BAT;

 
/


GRANT EXECUTE ON ABC.PKG_ABCREPORTS_61BAT TO POSSEEXTENSIONS;
