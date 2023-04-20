CREATE OR REPLACE package ABC.PKG_LQS AS
  /*---------------------------------------------------------------------------
  * Types
  *-------------------------------------------------------------------------*/
  SUBTYPE udt_Id IS api.pkg_Definition.udt_Id;
  SUBTYPE udt_EndPoint IS api.pkg_definition.udt_EndPoint;
  SUBTYPE udt_ObjectList IS api.udt_ObjectList;

  PROCEDURE GetLicense(p_jobid udt_Id);
  PROCEDURE GetLicensees;
  PROCEDURE GetLicenseTypes;
  PROCEDURE GetConditions;
  PROCEDURE GetTransferData;
  PROCEDURE GetOperatingRestrictions;
  PROCEDURE GetDisciplinaryAction;
  PROCEDURE GetDisciplianryHist;
  PROCEDURE GetHolds;
  PROCEDURE GetEscrow;

END pkg_LQS;
/
