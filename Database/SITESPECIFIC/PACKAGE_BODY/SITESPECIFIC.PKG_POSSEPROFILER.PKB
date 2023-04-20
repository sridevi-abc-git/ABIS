CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_posseprofiler
AS
    -- **************************************************************************
    -- File:        PKG_POSSEPROFILER.PKB
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

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    ----------------------------------------------------------------------------
    -- ProfileColumns() -- PUBLIC
    ----------------------------------------------------------------------------
    PROCEDURE profilecolumns(a_maxrows       PLS_INTEGER DEFAULT 10,
                             a_continue      BOOLEAN DEFAULT TRUE)
    IS
        t_objectdefs        api.pkg_definition.udt_objectdeflist;
        t_objectdefscount   PLS_INTEGER;
        t_objectdefid       api.pkg_definition.udt_objectdef;
        t_index             PLS_INTEGER;
        t_objectdefname     VARCHAR2(30);
        t_objectids         api.pkg_definition.udt_idlist;
        t_objectdeftypeid   PLS_INTEGER;

        t_objectcount       PLS_INTEGER;
        t_starttime         TIMESTAMP;
        t_endtime           TIMESTAMP;
        t_elapsedseconds    NUMBER;
        t_dummy             VARCHAR2(4000);
        t_error             VARCHAR2(4000);

        CURSOR c_columndefs(a_objectdefid NUMBER)
        IS
            SELECT a.columndefid, a.name
              FROM api.columndefs a
             WHERE a.objectdefid = a_objectdefid
               AND a.active = 'Y'
               AND a.iscompletelybound = 'Y'
               AND a.canevaluateindatabase = 'Y'
               AND a.name NOT LIKE 'zzz%'
               AND NOT EXISTS
                       (SELECT 1
                          FROM posseprofilerresults r
                         WHERE r.objectdefid = a_objectdefid
                           AND r.columndefid = a.columndefid);
    BEGIN
        --pkg_debug.enable('profiler');
        pkg_debug.suspend;

          -- get a list of the Object Defs to profile
          SELECT a.objectdefid
            BULK COLLECT INTO t_objectdefs
            FROM api.objectdefs a
           WHERE a.objectdeftypeid IN (1,
                                       2,
                                       3,
                                       4,
                                       5)
             AND a.name NOT LIKE 'zzz%'
        ORDER BY objectdeftypeid, objectdefid;

        t_objectdefscount   := t_objectdefs.COUNT;

        FOR t_index IN 1 .. t_objectdefscount
        LOOP
            t_objectdefid   := t_objectdefs(t_index);

            SELECT a.name, a.objectdeftypeid
              INTO t_objectdefname, t_objectdeftypeid
              FROM api.objectdefs a
             WHERE a.objectdefid = t_objectdefid;

            pkg_debug.putsingleline(t_objectdefname);

            IF NOT a_continue THEN
                -- Delete profile rows for this object def
                DELETE FROM posseprofilerresults a
                      WHERE a.objectdefid = t_objectdefid;

                COMMIT;
            END IF;

            -- get random sample of object ids for this object def
            SELECT objectid
              BULK COLLECT INTO t_objectids
              FROM api.objects SAMPLE(50)
             WHERE objectdeftypeid = t_objectdeftypeid
               AND objectdefid = t_objectdefid
               AND ROWNUM <= a_maxrows;

            IF t_objectids.COUNT < a_maxrows THEN
                SELECT objectid
                  BULK COLLECT INTO t_objectids
                  FROM api.objects SAMPLE(99)
                 WHERE objectdeftypeid = t_objectdeftypeid
                   AND objectdefid = t_objectdefid
                   AND ROWNUM <= a_maxrows;
            END IF;

            -- loop through the column defs for this object def
            FOR i IN c_columndefs(t_objectdefid)
            LOOP
                t_error            := NULL;
                t_objectcount      := 0;
                t_elapsedseconds   := 0;

                -- evaluate the column def multiple times
                FOR x IN 1 .. t_objectids.COUNT
                LOOP
                    t_objectcount   := t_objectcount + 1;
                    t_starttime     := SYSTIMESTAMP;

                    BEGIN
                        t_dummy   :=
                            api.pkg_columnquery.VALUE(t_objectids(x), i.name);
                    EXCEPTION
                        WHEN OTHERS THEN
                            t_error   := SQLERRM;
                            EXIT;
                    END;

                    t_endtime       := SYSTIMESTAMP;

                    t_elapsedseconds   :=
                          t_elapsedseconds
                        +   (  EXTRACT(HOUR FROM t_endtime)
                             - EXTRACT(HOUR FROM t_starttime))
                          * 3600
                        +   (  EXTRACT(MINUTE FROM t_endtime)
                             - EXTRACT(MINUTE FROM t_starttime))
                          * 60
                        + (  EXTRACT(SECOND FROM t_endtime)
                           - EXTRACT(SECOND FROM t_starttime));

                    -- don't evaluate any more if it is taking too long
                    IF t_elapsedseconds > 300 THEN
                        EXIT;
                    END IF;
                END LOOP;

                INSERT INTO posseprofilerresults(objectdefid,
                                                 columndefid,
                                                 objectdefname,
                                                 columndefname,
                                                 numberofrows,
                                                 secondsperrow,
                                                 createdtimestamp,
                                                 errormessage)
                         VALUES (
                                    t_objectdefid,
                                    i.columndefid,
                                    t_objectdefname,
                                    i.name,
                                    t_objectcount,
                                    CASE
                                        WHEN t_objectcount = 0 THEN 0
                                        ELSE t_elapsedseconds / t_objectcount
                                    END,
                                    SYSTIMESTAMP,
                                    t_error);

                COMMIT;
            END LOOP;
        END LOOP;

        pkg_debug.putsingleline('Done PosseProfiler');
    END profilecolumns;
END pkg_posseprofiler;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_POSSEPROFILER TO POSSESYS;
