CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_dailyreport
AS
    -- **************************************************************************
    -- File:        PKG_DAILYREPORT.pkb
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
    PROCEDURE findabc22report(
        a_investigationdate          DATE,
        a_investigationdateto        DATE,
        a_dup_lrinvestigator         VARCHAR2,
        a_objects         OUT NOCOPY api.udt_objectlist)
    IS
    /*
      t_UnfilteredObjects api.udt_ObjectList;*/

    BEGIN
        pkg_debug.putline('This is a Test');
        a_objects   := api.udt_objectlist(); /*
 t_UnfilteredObjects := api.udt_ObjectList();*/
        extension.pkg_cxproceduralsearch.initializesearch('o_ABC22Report');
        pkg_debug.putline('********1');
        extension.pkg_cxproceduralsearch.searchbyindex('InvestigationDate',
                                                       a_investigationdate,
                                                       a_investigationdateto);
        pkg_debug.putline('********2' || a_dup_lrinvestigator);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LRInvestigator',
                                                       a_dup_lrinvestigator,
                                                       NULL,
                                                       TRUE);
        pkg_debug.putline('********3');
        extension.pkg_cxproceduralsearch.performsearch(a_objects,
                                                       'and',
                                                       'none');
        pkg_debug.putline('********4');
    END findabc22report;

    /*---------------------------------------------------------------------------
      * GetInvUserLogForInvFieldVisit() -- PUBLIC
      * this will relate the InvestigationUserLogs to the InvestigationFieldVisit Object
      *-------------------------------------------------------------------------*/
    PROCEDURE getinvuserlogforabc22report(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_investigationdate   DATE
            := api.pkg_columnquery.datevalue(a_objectid, 'InvestigationDate');
        t_lrinvestigator      VARCHAR2(60)
            := api.pkg_columnquery.VALUE(a_objectid, 'LRInvestigator');
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c IN (SELECT il.objectid objectid
                    FROM query.l_investigationuserlog il
                   WHERE il.fieldvisit = 'Y'
                     AND il.username = t_lrinvestigator
                     AND il.logdate = TRUNC(t_investigationdate))
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.objectid);
        END LOOP;
    END getinvuserlogforabc22report;

    /*---------------------------------------------------------------------------
      * GetLRUserLogsForInvFieldVisit() -- PUBLIC
      * this will relate the LRUserLogs to the InvestigationFieldVisit Object
      *-------------------------------------------------------------------------*/
    PROCEDURE getlruserlogsforabc22report(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_investigationdate   DATE
            := api.pkg_columnquery.datevalue(a_objectid, 'InvestigationDate');
        t_lrinvestigator      VARCHAR2(60)
            := api.pkg_columnquery.VALUE(a_objectid, 'LRInvestigator');
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c IN (SELECT l.objectid objectid
                    FROM query.l_lruserlog l
                   WHERE l.fieldvisit = 'Y'
                     AND l.username = t_lrinvestigator
                     AND l.logdate = TRUNC(t_investigationdate))
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.objectid);
        END LOOP;
    END getlruserlogsforabc22report;

    /*---------------------------------------------------------------------------
    * RelateUserToInvestFieldVisit() -- PUBLIC
    * this will relate the current user if that user has the access group LR or Investigator
    *-------------------------------------------------------------------------*/
    PROCEDURE relateusertoabc22report(a_objectid udt_id, a_asofdate DATE)
    IS
        t_currentuserid       udt_id := api.pkg_securityquery.effectiveuserid();
        t_userendpointid      udt_id
            := api.pkg_configquery.endpointidforname('o_ABC22Report',
                                                     'Users');
        t_userobjectid        udt_id;
        t_newrelationshipid   udt_id;
        t_userrelidcount      NUMBER;
    BEGIN
        SELECT u.objectid
          INTO t_userobjectid
          FROM query.users u
         WHERE u.userid = t_currentuserid;



        api.pkg_columnupdate.setvalue(a_objectid,
                                      'InvestigationDate',
                                      TRUNC(SYSDATE));


        t_newrelationshipid   :=
            api.pkg_relationshipupdate.new(t_userendpointid,
                                           a_objectid,
                                           t_userobjectid);
    END relateusertoabc22report;
END pkg_dailyreport;
/
