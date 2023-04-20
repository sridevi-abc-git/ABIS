CREATE OR REPLACE package SITESPECIFIC.pkg_Michael is

  -- Author  : Michael Morgan
  -- Created : 9/28/2011 9:13:51 AM
  -- Purpose : MM Testing
  
 /*------------------------------------------------------------------------*
  * Types declaration
  *------------------------------------------------------------------------*/
  subtype udt_ID is api.pkg_Definition.udt_ID;
  subtype udt_idlist is api.pkg_definition.udt_IdList;
  subtype udt_StringList is api.pkg_Definition.udt_StringList;
  type VAR is varray(100) of number(1);
  subtype udt_NumberList is api.pkg_Definition.udt_NumberList;
  subtype udt_ObjectList is api.udt_ObjectList;

-----------------------------------
Procedure TransferPayment(a_ObjectId        number,
                          a_AsOfDate        date);

end pkg_Michael;

 
/


GRANT EXECUTE ON SITESPECIFIC.PKG_MICHAEL TO CONV;

GRANT EXECUTE ON SITESPECIFIC.PKG_MICHAEL TO POSSEEXTENSIONS;
