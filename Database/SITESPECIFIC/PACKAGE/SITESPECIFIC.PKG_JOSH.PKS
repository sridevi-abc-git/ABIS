CREATE OR REPLACE package SITESPECIFIC.pkg_Josh as

  -- Public type declarations

  subtype udt_idlist is api.pkg_definition.udt_IdList;
  subtype udt_NumberList is api.pkg_Definition.udt_NumberList;
  subtype udt_ptdef is api.pkg_definition.udt_ProcessType;
  subtype udt_Id is api.pkg_Definition.udt_Id;

  procedure FindPaymentTransactions(
    a_LicenseNumber varchar2,
	  a_LicenseTypeCode varchar2,
	  a_ObjectList out api.udt_ObjectList
  );
end pkg_Josh;

 
/
