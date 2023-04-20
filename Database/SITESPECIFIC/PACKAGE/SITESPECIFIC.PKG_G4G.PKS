CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_g4g
AS
    -- **************************************************************************
    -- File:        PKG_G4G.pks
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*---------------------------------------------------------------------------
  * FindFiscalYear() -- PUBLIC
  *-------------------------------------------------------------------------*/
    PROCEDURE findfiscalyear(a_year                       NUMBER,
                             a_objects         OUT NOCOPY api.udt_objectlist);

    /*---------------------------------------------------------------------------
    * GetDistrictOffice() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE relateofficesanddeptavg(a_objectid udt_id, a_asofdate DATE);

    /*----------------------------------------------------------
      ABC19ValidateOperaDate() -- PUBLIC
      this will varify that the numbers entered are valide for that day and year on the ABC19 Monthly Header.
    ------------------------------------------------------------*/

    PROCEDURE abc19validateoperadate(a_objectid      udt_id,
                                     a_asofdate      DATE,
                                     a_monthname     VARCHAR2,
                                     a_year          NUMBER);
END pkg_g4g;
/
