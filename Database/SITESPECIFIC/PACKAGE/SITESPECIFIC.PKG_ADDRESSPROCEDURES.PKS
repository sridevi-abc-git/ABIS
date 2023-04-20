CREATE OR REPLACE package SITESPECIFIC.pkg_AddressProcedures as

  subtype udt_Boolean is api.pkg_Definition.udt_Boolean;
  subtype udt_Id is api.pkg_Definition.udt_Id;

  /*---------------------------------------------------------------------------
   * AddressedObjectDeleting()
   *   Prevent an Addressed Object from being deleted if there are any
   * descendents.
   *-------------------------------------------------------------------------*/
  procedure AddressedObjectDeleting (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  );

  /*---------------------------------------------------------------------------
   * AddressHistoryChanged()
   *   Duplicate FormattedAddress, and verify InheritanceChain.
   *-------------------------------------------------------------------------*/
  procedure AddressHistoryChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  );

  /*---------------------------------------------------------------------------
   * AddressSearch()
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
  );

  /*---------------------------------------------------------------------------
   * MaintainedAddressChanged()
   *   Ensure only one primary address, and generate the Address History
   * objects for a maintained address.
   *-------------------------------------------------------------------------*/
  procedure MaintainedAddressChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date,
    a_IsPrimary                         udt_Boolean
  );

  /*---------------------------------------------------------------------------
   * MaintainedAddressDeleting()
   *   Ensure that deleting the MaintainedAddress object will not violate any
   * business rules.  Raise an informative exception if necessary.
   *-------------------------------------------------------------------------*/
  procedure MaintainedAddressDeleting (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date,
    a_IsPrimary                         udt_Boolean
  );

  /*---------------------------------------------------------------------------
   * ObjectWithAddressingChanged()
   *   If there isn't one, create a related AddressedObject.  Force the
   * SourceObjectId, to ensure that it has been created.
   *-------------------------------------------------------------------------*/
  procedure ObjectWithAddressingChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  );

  /*---------------------------------------------------------------------------
   * StreetNameChanged()
   *   Set the stored formatted street name, and re-verify all maintained
   * addresses.
   *-------------------------------------------------------------------------*/
  procedure StreetNameChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  );

  /*---------------------------------------------------------------------------
   * StreetNameComponentChanged()
   *   Re-verify Street Names.
   *-------------------------------------------------------------------------*/
  procedure StreetNameComponentChanged (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  );

  /*---------------------------------------------------------------------------
   * StreetNameComponentDeleting()
   *   Ensure that no Street Names exist with the component.
   *-------------------------------------------------------------------------*/
  procedure StreetNameComponentDeleting (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  );

  /*---------------------------------------------------------------------------
   * StreetNameDeleting()
   *   Ensure that no Maintained Addresses exist with the Street Name.
   *-------------------------------------------------------------------------*/
  procedure StreetNameDeleting (
    a_ObjectId                          udt_Id,
    a_AsOfDate                          date
  );

end pkg_AddressProcedures;

/
