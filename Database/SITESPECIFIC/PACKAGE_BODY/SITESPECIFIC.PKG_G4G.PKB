CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_g4g
AS
    -- **************************************************************************
    -- File:        PKG_G4G.pkb
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
      * FindFiscalYear() -- PUBLIC
      *-------------------------------------------------------------------------*/
    PROCEDURE findfiscalyear(a_year                       NUMBER,
                             a_objects         OUT NOCOPY api.udt_objectlist)
    IS
    /*
      t_UnfilteredObjects api.udt_ObjectList;*/

    BEGIN
        a_objects   := api.udt_objectlist(); /*
 t_UnfilteredObjects := api.udt_ObjectList();*/
        extension.pkg_cxproceduralsearch.initializesearch('o_FiscalYear');

        extension.pkg_cxproceduralsearch.searchbyindex('Year',
                                                       a_year,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.performsearch(a_objects,
                                                       'and',
                                                       'none');
    END findfiscalyear;

    /*------------------------------------------------------------------------*
       * RelateOfficesAndDeptAvg() -- Public
       * Releate District Offices and create and relate a G4GLineItem Object and name the column "Dept. Average"
       * it will also Relate G4G
       *------------------------------------------------------------------------*/
    PROCEDURE relateofficesanddeptavg(a_objectid udt_id, a_asofdate DATE)
    IS
        t_g4glineitemdefid    udt_id
            := api.pkg_configquery.objectdefidforname('o_G4GLineItem');
        t_endpointdeptave     udt_id
            := api.pkg_configquery.endpointidforname('o_FiscalYear',
                                                     'G4G01DeptAverage');
        t_endpointg4g06       udt_id
            := api.pkg_configquery.endpointidforname('o_FiscalYear', 'G4G06');
        t_endpointg4g07       udt_id
            := api.pkg_configquery.endpointidforname('o_FiscalYear', 'G4G07');
        t_newobjectid         udt_id;
        t_newrelationshipid   udt_id;
        t_newofficerelid      udt_id;
        t_endpointoffice      udt_id
            := api.pkg_configquery.endpointidforname('o_FiscalYear',
                                                     'Office');
    BEGIN
        /*this will relate the o_G4GLineItem for the G4G report and name the TitleColumn to "Dept. Average"*/
        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointdeptave,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'Dept. Average');
        /*this will create and related the o_G4GLineItem 8 times for the G4G 06 and set the TitleColumn*/

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'ABC Premises Visited');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '1');

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'ABC Violations');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '2');

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'ABC''s Percentage');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '3');

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'Local Premises Visited');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '4');

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'Local Violations');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '5');

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'Local''s Percentage');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '6');

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'Total Premises Visited');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '7');

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'Total Violations');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '8');

        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g06,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'Total Percentage');
        api.pkg_columnupdate.setvalue(t_newobjectid, 'SortColumn', '9');

        -- this will create the G4G line item for the G4G-07 and set the title column to State Percentage
        t_newobjectid         := api.pkg_objectupdate.new(t_g4glineitemdefid);
        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_endpointg4g07,
                                           a_objectid,
                                           t_newobjectid);
        api.pkg_columnupdate.setvalue(t_newobjectid,
                                      'TitleColumn',
                                      'State Percentage');

        /*This will relate all the DISTRICT offices*/

        FOR c IN (SELECT o.objectid officeobjid
                    FROM query.o_office o
                   WHERE o.isactive = 'Y')
        LOOP
            t_newofficerelid   :=
                api.pkg_relationshipupdate.new(t_endpointoffice,
                                               a_objectid,
                                               c.officeobjid);
        END LOOP;
    END relateofficesanddeptavg;


    /*------------------------------------------------------------------------*
       * ABC19ValidateOperaDate() -- PUBLIC
       * this will varify that the numbers entered are valide for that day and year on the ABC19 Monthly.
       *------------------------------------------------------------------------*/
    PROCEDURE abc19validateoperadate(a_objectid      udt_id,
                                     a_asofdate      DATE,
                                     a_monthname     VARCHAR2,
                                     a_year          NUMBER)
    IS
        t_test   DATE;
    BEGIN
        FOR c
            IN (SELECT p.programtype, p.operationdate
                  FROM query.o_abc19programdetail  p
                       JOIN api.relationships r
                           ON r.fromobjectid = p.objectid
                 WHERE r.toobjectid = a_objectid)
        LOOP
            sitespecific.pkg_utils.validatedate(a_objectid,
                                                a_asofdate,
                                                c.programtype,
                                                a_monthname,
                                                c.operationdate,
                                                a_year);
        END LOOP;
    END abc19validateoperadate;
END pkg_g4g;
/
