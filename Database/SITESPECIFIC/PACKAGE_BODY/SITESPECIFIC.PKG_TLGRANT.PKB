CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_tlgrant
IS
    -- **************************************************************************
    -- File:        PKG_TLGRANT.PKB
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
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    /******************************************************************
    getLicenseInformation is run on LicenseTRacker Object supplied license number
    confirm that it is a valid license and get the following DBA, Prem Address
    ******************************************************************/
    PROCEDURE getlicenseinformation(a_objectid      udt_id,
                                    a_asofdate      DATE,
                                    a_licensenumber VARCHAR2)
    IS
        t_licenseobjectid    VARCHAR2(10);
        t_object             api.udt_objectlist;
        t_dba                VARCHAR2(4000);
        t_premisesaddress    VARCHAR2(4000);
        t_premaddress1line   VARCHAR2(4000);
    BEGIN
        t_object   := api.udt_objectlist();
        t_object.delete();

        extension.pkg_cxproceduralsearch.initializesearch('j_License');
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     a_licensenumber,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        --    extension.pkg_cxproceduralsearch.SearchByIndex('ExternalFileNum', a_LicenseNumber, null, false);
        extension.pkg_cxproceduralsearch.performsearch(t_object,
                                                       'and',
                                                       'none');

        IF t_object.COUNT >= 1 THEN
            t_licenseobjectid   := t_object(1).objectid;


            SELECT NVL(l.doingbusinessas, l.primarylicensee),
                   l.premisesaddress,
                   l.premaddress1line
              INTO t_dba, t_premisesaddress, t_premaddress1line
              FROM query.j_license l
             WHERE l.objectid = t_licenseobjectid;

            IF t_dba IS NOT NULL THEN
                api.pkg_columnupdate.setvalue(a_objectid, 'DBA', t_dba);
            END IF;

            IF t_premisesaddress IS NOT NULL THEN
                api.pkg_columnupdate.setvalue(a_objectid,
                                              'PremisesAddress',
                                              t_premisesaddress);
            END IF;

            IF t_premaddress1line IS NOT NULL THEN
                api.pkg_columnupdate.setvalue(a_objectid,
                                              'Address1Line',
                                              t_premaddress1line);
            END IF;

            api.pkg_columnupdate.setvalue(a_objectid,
                                          'LicenseObjectId',
                                          t_licenseobjectid);
        ELSE
            api.pkg_errors.raiseerror(
                -20000,
                   'License Number: '
                || a_licensenumber
                || ' is not valid license number');
        END IF;
    END getlicenseinformation;
END pkg_tlgrant;
/
