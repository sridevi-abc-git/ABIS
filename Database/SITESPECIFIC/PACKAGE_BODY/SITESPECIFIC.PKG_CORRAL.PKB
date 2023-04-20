CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_corral
IS
    -- **************************************************************************
    -- File:        PKG_CORRAL.pkb
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
     * Types - PUBLIC
     *-------------------------------------------------------------------------*/
    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    SUBTYPE udt_stringlist IS api.pkg_definition.udt_stringlist;

    /*---------------------------------------------------------------------------
     * NotifyCorralForRelatedObjects() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE notifycorralforrelatedobjects(a_objectid      udt_id,
                                            a_asofdate      DATE,
                                            a_endpointnames VARCHAR2)
    IS
        t_args         VARCHAR2(4000);
        t_scheduleid   udt_id;
    BEGIN
        scheduler.pkg_scheduler.addargument(
            t_args,
            'procedure',
            'SiteSpecific.pkg_Corral.ScheduledNotifyCorralForRelObj');
        scheduler.pkg_scheduler.addargument(t_args,
                                            'effectiveuser',
                                            'POSSESYS');
        scheduler.pkg_scheduler.addargument(t_args, 'arg1', a_objectid);
        scheduler.pkg_scheduler.addargument(t_args, 'arg2', a_endpointnames);
        t_scheduleid   :=
            scheduler.pkg_scheduler.scheduleitem(
                SYSDATE,
                2,
                'nc_0011_executeprocedureasposseuser',
                t_args,
                'Notify Corral for objects related to: ' || a_objectid);
    END;

    PROCEDURE schedulednotifycorralforrelobj(a_objectid      VARCHAR2,
                                             a_endpointnames VARCHAR2)
    IS
        t_endpointnamelist   udt_stringlist;
        t_endpointid         udt_id;
        t_relatedobjects     udt_idlist;
        t_objectdefid        udt_id;
        t_objectid           udt_id := TO_NUMBER(a_objectid);
    BEGIN
        SELECT objectdefid
          INTO t_objectdefid
          FROM api.objects
         WHERE objectid = t_objectid;

        t_endpointnamelist   :=
            extension.pkg_utils.split(a_endpointnames, ',');

        FOR i IN 1 .. t_endpointnamelist.COUNT
        LOOP
            t_endpointid   :=
                api.pkg_configquery.endpointidforname(t_objectdefid,
                                                      t_endpointnamelist(i));
            t_relatedobjects   :=
                api.pkg_objectquery.relatedobjects(t_objectid,
                                                   t_endpointid,
                                                   SYSDATE);

            FOR j IN 1 .. t_relatedobjects.COUNT
            LOOP
                api.pkg_objectupdate.setobjecttosynchronize(
                    t_relatedobjects(j));
            END LOOP;
        END LOOP;
    END;
END pkg_corral;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_CORRAL TO POSSEEXTENSIONS;

GRANT EXECUTE ON SITESPECIFIC.PKG_CORRAL TO PSERVERSYS;
