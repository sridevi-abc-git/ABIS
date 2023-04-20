CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_nathansecurity
AS
    -- **************************************************************************
    -- File:        PKG_NATHANSECURITY.PKB
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
    * AddOfficeAccessGroup() -- PRIVATE
    *-------------------------------------------------------------------------*/
    PROCEDURE addofficeaccessgroup(g_object udt_id, a_asofdate DATE)
    IS
        t_userobjectid    udt_id;
        t_accessgroupid   udt_id;
    BEGIN
        SELECT o.userobjectid
          INTO t_userobjectid
          FROM query.r_usersecondaryoffice o
         WHERE o.relationshipid = g_object;

        SELECT a.accessgroupid
          INTO t_accessgroupid
          FROM api.accessgroups a
         WHERE a.description = api.pkg_columnquery.VALUE(
                                   (SELECT o.officeobjectid
                                      FROM query.r_usersecondaryoffice o
                                     WHERE o.relationshipid = g_object),
                                   'OfficeName');

        api.pkg_userupdate.addtoaccessgroup(t_userobjectid, t_accessgroupid);
    END;

    /*---------------------------------------------------------------------------
    * RemoveOfficeAccessGroup() -- PRIVATE
    *-------------------------------------------------------------------------*/
    PROCEDURE removeofficeaccessgroup(g_object udt_id, a_asofdate DATE)
    IS
        t_userobjectid    udt_id;
        t_accessgroupid   udt_id;
    BEGIN
        SELECT o.userobjectid
          INTO t_userobjectid
          FROM query.r_usersecondaryoffice o
         WHERE o.relationshipid = g_object;

        SELECT a.accessgroupid
          INTO t_accessgroupid
          FROM api.accessgroups a
         WHERE a.description = api.pkg_columnquery.VALUE(
                                   (SELECT o.officeobjectid
                                      FROM query.r_usersecondaryoffice o
                                     WHERE o.relationshipid = g_object),
                                   'OfficeName');

        api.pkg_userupdate.removefromaccessgroup(t_userobjectid,
                                                 t_accessgroupid);
    END;
END pkg_nathansecurity;
/
