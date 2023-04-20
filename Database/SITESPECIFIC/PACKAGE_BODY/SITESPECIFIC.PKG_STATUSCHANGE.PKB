CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_STATUSCHANGE"
IS
    -- **************************************************************************
    -- File:        PKG_STATUSCHANGE.PKB
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

    /*--------------------------
    --  LTStatusChange() - PUBLIC
    */
    --------------------------
    PROCEDURE ltstatuschange(a_relationshipid udt_id,
                             a_asofdate      DATE,
                             a_status        VARCHAR2,
                             a_statusdate    DATE)
    IS
        t_currentstatusname     VARCHAR2(6);
        t_sltstatuschangeid     NUMBER;
        t_jobstatustype         CHAR(1);
        t_jobtypeid             udt_id;
        t_licensetypejobid      udt_id;
        t_statusname            VARCHAR2(6);
        t_fromobjectid          udt_id;
        t_toobjectid            udt_id;
        t_storedeffectivedate   DATE;
    BEGIN
        -- Get the License Type Job Id
        BEGIN
            SELECT r.licensetypejobid,
                   r.licensetypejobid,
                   r.licensetypecategoryobjectid
              INTO t_licensetypejobid, t_fromobjectid, t_toobjectid
              FROM query.r_licensetypeltcatsecondary r
             WHERE r.relationshipid = a_relationshipid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       SQLERRM
                    || '. Cannot select IDs from r_LicenseTypeLTCatSecondary. ');
        END;

        -- Get the Status Tag for the Status Name that was set on the Rel
        BEGIN
            SELECT s.tag
              INTO t_statusname
              FROM api.statuses s
             WHERE UPPER(s.description) = a_status;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    SQLERRM || '. Cannot find status ' || a_status || '.');
        END;

        t_storedeffectivedate   :=
            api.pkg_columnquery.datevalue(a_relationshipid, 'StatusDate');

        BEGIN
            -- check if an existing record exists in the table for a Status change
            SELECT sc.sltstatuschangeid, sc.statusname, js.statustype
              INTO t_sltstatuschangeid, t_currentstatusname, t_jobstatustype
              FROM sltstatuschange_t  sc
                   JOIN query.r_licensetypeltcatsecondary r
                       ON sc.relationshipid = r.relationshipid
                   JOIN api.jobs j ON r.licensetypejobid = j.jobid
                   JOIN api.jobstatuses js
                       ON j.jobtypeid = js.jobtypeid
                      AND js.statusid = (SELECT st.statusid
                                           FROM api.statuses st
                                          WHERE st.tag = t_statusname)
             WHERE sc.relationshipid = a_relationshipid
               AND sc.mostrecent = 'Y';

            -- if it does, and the new status and current status don't match, create a new row
            IF t_statusname != t_currentstatusname THEN
                UPDATE sltstatuschange_t
                   SET effectiveenddate = SYSDATE, mostrecent = 'N'
                 WHERE sltstatuschangeid = t_sltstatuschangeid;

                INSERT INTO sltstatuschange_t(sltstatuschangeid,
                                              relationshipid,
                                              statusname,
                                              effectivestartdate,
                                              effectiveenddate,
                                              mostrecent,
                                              statustype,
                                              effectiveuser,
                                              statusdate,
                                              fromobjectid,
                                              toobjectid)
                     VALUES (ltjobstatuschange_s.NEXTVAL,
                             a_relationshipid,
                             t_statusname,
                             SYSDATE,
                             NULL,
                             'Y',
                             t_jobstatustype,
                             api.pkg_securityquery.effectiveuser,
                             a_statusdate,
                             t_fromobjectid,
                             t_toobjectid);

                --Set Effective Date (Status Date) to the sysdate
                -- api.pkg_errors.RaiseError(-20000, 'Error, StatusName: ' || t_StatusName || ' CurrentStatusName: ' || t_CurrentStatusName);
                api.pkg_columnupdate.setvalue(
                    a_relationshipid,
                    'StatusDate',
                    NVL(t_storedeffectivedate, SYSDATE));
            ELSE
                UPDATE sltstatuschange_t
                   SET statusdate   = a_statusdate
                 WHERE mostrecent = 'Y'
                   AND relationshipid = a_relationshipid;

                --If the Status is In a Complete or Cancelled Status Clear the batch flags
                IF t_jobstatustype IN ('X', 'C') THEN
                    pkg_batchtype.setbatchflagswrap(a_relationshipid,
                                                    SYSDATE,
                                                    a_relationshipid);
                END IF;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- when no data is found in the above select statement
                SELECT jsta.statustype
                  INTO t_jobstatustype
                  FROM api.jobstatuses  jsta
                       JOIN api.statuses sta ON jsta.statusid = sta.statusid
                 WHERE sta.tag = t_statusname
                   AND jsta.jobtypeid = (SELECT jobtypeid
                                           FROM api.jobs
                                          WHERE jobid = t_licensetypejobid);

                INSERT INTO sltstatuschange_t(sltstatuschangeid,
                                              relationshipid,
                                              statusname,
                                              effectivestartdate,
                                              effectiveenddate,
                                              mostrecent,
                                              statustype,
                                              effectiveuser,
                                              statusdate,
                                              fromobjectid,
                                              toobjectid)
                     VALUES (ltjobstatuschange_s.NEXTVAL,
                             a_relationshipid,
                             t_statusname,
                             SYSDATE,
                             NULL,
                             'Y',
                             t_jobstatustype,
                             api.pkg_securityquery.effectiveuser,
                             a_statusdate,
                             t_fromobjectid,
                             t_toobjectid);

                --Set Effective Date (Status Date) to the sysdate
                --api.pkg_errors.RaiseError(-20000, 'Error, StatusName: ' || t_StatusName || ' CurrentStatusName: ' || t_CurrentStatusName);
                api.pkg_columnupdate.setvalue(
                    a_relationshipid,
                    'StatusDate',
                    NVL(t_storedeffectivedate, SYSDATE));
        END;

        IF t_storedeffectivedate IS NOT NULL THEN
            api.pkg_columnupdate.removevalue(a_relationshipid,
                                             'StoredEffectiveDate');
        END IF;
    END ltstatuschange;

    /*---------------------------------------------------------
    --  Log Status Changes of Primary License Type Objects
    */
    ---------------------------------------------------------

    PROCEDURE pltostatuschange(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_status        VARCHAR2,
                               a_statusdate    DATE)
    IS
        t_currentstatusname            VARCHAR2(6);
        t_currentstatustype            CHAR(1);
        t_jobstatuschangeid            NUMBER;
        t_jobstatustype                CHAR(1);
        t_jobtypeid                    udt_id;
        t_primarylicensetypeobjectid   udt_id;
        t_statusname                   VARCHAR2(6);
    BEGIN
        -- Get the Status Tag for the Status Name that was set on the Rel
        BEGIN
            SELECT s.tag, NVL(jsa.statustype, jslt.statustype)
              INTO t_statusname, t_jobstatustype
              FROM api.statuses  s
                   LEFT OUTER JOIN api.jobstatuses jsa
                       ON jsa.statusid = s.statusid
                      AND jsa.jobtypeid IN (SELECT j.jobtypeid
                                              FROM api.jobtypes j
                                             WHERE j.name = 'j_Application')
                   FULL OUTER JOIN api.jobstatuses jslt
                       ON jslt.statusid = s.statusid
                      AND jslt.jobtypeid IN (SELECT j.jobtypeid
                                               FROM api.jobtypes j
                                              WHERE j.name = 'j_LicenseType')
             WHERE UPPER(s.description) = a_status;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    SQLERRM || '. Cannot find status ' || a_status || '.');
        END;

        t_primarylicensetypeobjectid   := a_objectid;

        BEGIN
            -- get the most reacent row, for the primary licenes type object, and to be used to make sure the status has changed
            SELECT jsc.statusname, jsc.statustype, jsc.jobstatuschangeid
              INTO t_currentstatusname,
                   t_currentstatustype,
                   t_jobstatuschangeid
              FROM extension.jobstatuschange_t jsc
             WHERE jsc.jobid = a_objectid
               AND jsc.mostrecent = 'Y';

            --If the status changed then log the change
            IF t_statusname <> t_currentstatusname THEN
                UPDATE extension.jobstatuschange_t
                   SET effectiveenddate = SYSDATE, mostrecent = 'N'
                 WHERE jobstatuschangeid = t_jobstatuschangeid;

                INSERT INTO extension.jobstatuschange_t(jobstatuschangeid,
                                                        jobid,
                                                        statusname,
                                                        statustype,
                                                        effectivestartdate,
                                                        effectiveenddate,
                                                        mostrecent,
                                                        effectiveuser,
                                                        statusdate)
                     VALUES (extension.jobstatuschange_s.NEXTVAL,
                             a_objectid,
                             t_statusname,
                             t_jobstatustype,
                             SYSDATE,
                             NULL,
                             'Y',
                             api.pkg_securityquery.effectiveuser,
                             a_statusdate);

                --Set Effective Date (Status Date) to the sysdate
                api.pkg_columnupdate.setvalue(a_objectid,
                                              'StatusDate',
                                              SYSDATE);
            ELSE
                UPDATE extension.jobstatuschange_t
                   SET statusdate   = a_statusdate
                 WHERE mostrecent = 'Y'
                   AND jobid = a_objectid;
            END IF;
	
         --   Update Geolocation    
            IF (t_currentstatustype != 'O'
            AND t_jobstatustype = 'O')
            OR (t_currentstatustype = 'O'
            AND t_jobstatustype != 'O') THEN
                --pkg_GIS.UpdatePointFromPLT(a_Objectid, a_AsOfDate, api.pkg_ColumnQuery.Value(a_ObjectId, 'ApplicationObjectId'));
                INSERT INTO sitespecific.giscalls
                         VALUES (
                                    a_objectid,
                                    api.pkg_columnquery.VALUE(
                                        a_objectid,
                                        'ApplicationObjectId'),
                                    'N',                     -- Processed = No
                                    sitespecific.giscalls_s.NEXTVAL);

                INSERT INTO toolbox.deferredprocedures
                     VALUES (toolbox.deferredprocedureid_s.NEXTVAL,
                             a_objectid,
                             'VERIFY',
                             TRUNC(SYSDATE),
                             'sitespecific.pkg_GIS.UpdatePointFromPLT',
                             'CONV',
                             NULL,
                             NULL,
                             NULL,
                             NULL);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO extension.jobstatuschange_t(jobstatuschangeid,
                                                        jobid,
                                                        statusname,
                                                        statustype,
                                                        effectivestartdate,
                                                        effectiveenddate,
                                                        mostrecent,
                                                        effectiveuser,
                                                        statusdate)
                     VALUES (extension.jobstatuschange_s.NEXTVAL,
                             a_objectid,
                             t_statusname,
                             t_jobstatustype,
                             SYSDATE,
                             NULL,
                             'Y',
                             api.pkg_securityquery.effectiveuser,
                             a_statusdate);

                --Set Effective Date (Status Date) to the sysdate
                api.pkg_columnupdate.setvalue(a_objectid,
                                              'StatusDate',
                                              SYSDATE);

                --Update Geolocation
                --pkg_GIS.UpdatePointFromPLT(a_Objectid, a_AsOfDate, api.pkg_ColumnQuery.Value(a_ObjectId, 'ApplicationObjectId'));

                INSERT INTO sitespecific.giscalls
                         VALUES (
                                    a_objectid,
                                    api.pkg_columnquery.VALUE(
                                        a_objectid,
                                        'ApplicationObjectId'),
                                    'N',                     -- Processed = No
                                    sitespecific.giscalls_s.NEXTVAL);

                INSERT INTO toolbox.deferredprocedures
                     VALUES (toolbox.deferredprocedureid_s.NEXTVAL,
                             a_objectid,
                             'VERIFY',
                             TRUNC(SYSDATE),
                             'sitespecific.pkg_GIS.UpdatePointFromPLT',
                             'CONV',
                             NULL,
                             NULL,
                             NULL,
                             NULL);
            WHEN OTHERS THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       SQLERRM
                    || '. Problem with selecting from JobStatusChange table for Primary License Type Objects.');
        END;
    END pltostatuschange;

    /*---------------------------------------------------------
    --  Log Status Changes of Secondary License Type Rels
    */
    ---------------------------------------------------------

    PROCEDURE sltrstatuschange(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_status        VARCHAR2,
                               a_statusdate    DATE)
    IS
        t_currentstatusname              VARCHAR2(6);
        t_jobstatuschangeid              NUMBER;
        t_jobstatustype                  CHAR(1);
        t_jobtypeid                      udt_id;
        t_secondarylicensetypecatrelid   udt_id;
        t_statusname                     VARCHAR2(6);
        t_js1                            VARCHAR2(20);
        t_js2                            VARCHAR2(20);
        t_fromobjectid                   udt_id;
        t_toobjectid                     udt_id;
    BEGIN
        -- Get the Status Tag for the Status Name that was set on the Rel

        BEGIN
            SELECT DISTINCT
                   CASE
                       WHEN rd.name = 'r_PriLTLTCatSecondary' THEN
                           'j_Application'
                       WHEN rd.name = 'r_LicenseTypeLTCatSecondary' THEN
                           'j_LicenseType'
                   END
                       js1,
                   CASE
                       WHEN rd.name = 'r_PriLTLTCatSecondary' THEN
                           'j_LicenseType'
                       WHEN rd.name = 'r_LicenseTypeLTCatSecondary' THEN
                           'j_Application'
                   END
                       js2
              INTO t_js1, t_js2
              FROM api.relationships  r
                   JOIN api.relationshipdefs rd
                       ON rd.relationshipdefid = r.relationshipdefid
             WHERE r.relationshipid = a_objectid;

            SELECT s.tag, NVL(jsa.statustype, jslt.statustype)
              INTO t_statusname, t_jobstatustype
              FROM api.statuses  s
                   LEFT OUTER JOIN api.jobstatuses jsa
                       ON jsa.statusid = s.statusid
                      AND jsa.jobtypeid IN (SELECT j.jobtypeid
                                              FROM api.jobtypes j
                                             WHERE j.name = t_js1)
                   FULL OUTER JOIN api.jobstatuses jslt
                       ON jslt.statusid = s.statusid
                      AND jslt.jobtypeid IN (SELECT j.jobtypeid
                                               FROM api.jobtypes j
                                              WHERE j.name = t_js2)
             WHERE UPPER(s.description) = a_status;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    SQLERRM || '. Cannot find status ' || a_status || '.');
        END;

        t_secondarylicensetypecatrelid   := a_objectid;

        SELECT fromobjectid, toobjectid
          INTO t_fromobjectid, t_toobjectid
          FROM api.relationships  r
               JOIN api.endpoints ep ON ep.endpointid = r.endpointid
         WHERE r.relationshipid = a_objectid
           AND ep.toobjectdefid =
               api.pkg_configquery.objectdefidforname(
                   'o_LicenseTypeCategory');

        BEGIN
            -- get the most reacent row, for the primary licenes type object, and to be used to make sure the status has changed
            SELECT jsc.statusname, jsc.sltstatuschangeid
              INTO t_currentstatusname, t_jobstatuschangeid
              FROM sitespecific.sltstatuschange_t jsc
             WHERE jsc.relationshipid = a_objectid
               AND jsc.mostrecent = 'Y';


            --If the status changed then log the change

            IF t_statusname <> t_currentstatusname THEN
                UPDATE sitespecific.sltstatuschange_t
                   SET effectiveenddate = SYSDATE, mostrecent = 'N'
                 WHERE sltstatuschangeid = t_jobstatuschangeid;

                INSERT INTO sitespecific.sltstatuschange_t(
                                sltstatuschangeid,
                                relationshipid,
                                statusname,
                                statustype,
                                effectivestartdate,
                                effectiveenddate,
                                mostrecent,
                                effectiveuser,
                                statusdate,
                                fromobjectid,
                                toobjectid)
                     VALUES (ltjobstatuschange_s.NEXTVAL,
                             t_secondarylicensetypecatrelid,
                             t_statusname,
                             t_jobstatustype,
                             SYSDATE,
                             NULL,
                             'Y',
                             api.pkg_securityquery.effectiveuser,
                             a_statusdate,
                             t_fromobjectid,
                             t_toobjectid);

                --Set Effective Date (Status Date) to the sysdate
                api.pkg_columnupdate.setvalue(a_objectid,
                                              'StatusDate',
                                              SYSDATE);
            ELSE
                UPDATE sitespecific.sltstatuschange_t
                   SET statusdate   = a_statusdate
                 WHERE relationshipid = a_objectid
                   AND mostrecent = 'Y';
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO sitespecific.sltstatuschange_t(
                                sltstatuschangeid,
                                relationshipid,
                                statusname,
                                statustype,
                                effectivestartdate,
                                effectiveenddate,
                                mostrecent,
                                effectiveuser,
                                statusdate,
                                fromobjectid,
                                toobjectid)
                     VALUES (ltjobstatuschange_s.NEXTVAL,
                             t_secondarylicensetypecatrelid,
                             t_statusname,
                             t_jobstatustype,
                             SYSDATE,
                             NULL,
                             'Y',
                             api.pkg_securityquery.effectiveuser,
                             a_statusdate,
                             t_fromobjectid,
                             t_toobjectid);

                --Set Effective Date (Status Date) to the sysdate
                api.pkg_columnupdate.setvalue(a_objectid,
                                              'StatusDate',
                                              SYSDATE);
            WHEN OTHERS THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       SQLERRM
                    || '. Problem with selecting from JobStatusChange table for Seconday License Type.');
        END;
    END sltrstatuschange;

    /*---------------------------------------------------------
    --Set Effective Date on Secondary License Types
    */
    ---------------------------------------------------------

    PROCEDURE slteffectivedate(a_objectid udt_id, a_asofdate DATE)
    IS
        t_effectivedate   DATE;
    BEGIN
        FOR c
            IN (SELECT slt.relationshipid, chs.processid, chs.effectivedate
                  FROM query.r_licensetypeltcatsecondary  slt
                       JOIN query.p_changestatus chs
                           ON chs.jobid = slt.licensetypejobid
                 WHERE slt.status IN ('ACTIVE',
                                      'REV PENDING',
                                      'RULE 64B',
                                      'SLMS HOLD',
                                      'SURRENDERED',
                                      'SUSPENDED')
                   AND chs.processid = a_objectid
                   AND chs.outcome IS NOT NULL)
        LOOP
            t_effectivedate   :=
                api.pkg_columnquery.datevalue(c.processid, 'EffectiveDate');


            IF t_effectivedate IS NOT NULL THEN
                api.pkg_columnupdate.setvalue(c.relationshipid,
                                              'StatusDate',
                                              t_effectivedate);
            END IF;
        END LOOP;
    END;
END pkg_statuschange;
/
