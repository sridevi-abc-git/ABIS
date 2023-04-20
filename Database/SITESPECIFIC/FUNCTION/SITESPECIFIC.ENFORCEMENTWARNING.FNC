CREATE OR REPLACE FUNCTION SITESPECIFIC.enforcementwarning(
    a_objectid      api.pkg_definition.udt_id)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        ENFORCEMENTWARNING.FNC
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
    t_openenfwarning   VARCHAR2(1);
    t_relatedobjids    api.udt_objectlist;
BEGIN
    FOR c
        IN (SELECT lec2.toobjectid
              FROM api.relationships  lec
                   JOIN api.relationships lec2
                       ON lec2.fromobjectid = lec.toobjectid
                      AND lec2.endpointid IN
                              (api.pkg_configquery.endpointidforname(
                                   'o_Company',
                                   'LegalEntity'),
                               api.pkg_configquery.endpointidforname(
                                   'o_Person',
                                   'LegalEntity'))
             WHERE lec.fromobjectid = a_objectid
               AND lec.endpointid IN
                       (api.pkg_configquery.endpointidforname(
                            'o_LegalEntity',
                            'Company'),
                        api.pkg_configquery.endpointidforname(
                            'o_LegalEntity',
                            'Person')))
    LOOP
        sitespecific.pkg_legalentity.getlicforle(c.toobjectid,
                                                 NULL,
                                                 t_relatedobjids);

        FOR w IN (SELECT objectid relid FROM TABLE(t_relatedobjids))
        LOOP
            BEGIN
                SELECT CASE
                           WHEN   SUM(
                                      NVL(
                                          (SELECT SUM(
                                                      api.pkg_columnquery.numericvalue(
                                                          t.toobjectid,
                                                          'OpenStatus'))
                                             FROM api.relationships t
                                            WHERE r.toobjectid =
                                                  t.fromobjectid
                                              AND t.endpointid =
                                                  (api.pkg_configquery.endpointidforname(
                                                       'j_Investigation',
                                                       'Accusation'))),
                                          0))
                                + SUM(NVL(i.openstatus, 0)) >
                                0 THEN
                               'Y'
                       END
                           opencount
                  INTO t_openenfwarning
                  FROM api.relationships  r
                       JOIN query.j_investigation i ON i.jobid = r.toobjectid
                 WHERE r.fromobjectid IN w.relid
                   AND r.endpointid =
                       (api.pkg_configquery.endpointidforname(
                            'j_License',
                            'Investigation'));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_openenfwarning   := 'N';
            END;

            EXIT WHEN t_openenfwarning = 'Y';
        END LOOP;

        EXIT WHEN t_openenfwarning = 'Y';

        sitespecific.pkg_legalentity.getp12licforle(c.toobjectid,
                                                    NULL,
                                                    t_relatedobjids);

        FOR x IN (SELECT objectid relid FROM TABLE(t_relatedobjids))
        LOOP
            BEGIN
                SELECT CASE
                           WHEN   SUM(
                                      NVL(
                                          (SELECT SUM(
                                                      api.pkg_columnquery.numericvalue(
                                                          t.toobjectid,
                                                          'OpenStatus'))
                                             FROM api.relationships t
                                            WHERE r.toobjectid =
                                                  t.fromobjectid
                                              AND t.endpointid =
                                                  (api.pkg_configquery.endpointidforname(
                                                       'j_Investigation',
                                                       'Accusation'))),
                                          0))
                                + SUM(NVL(i.openstatus, 0)) >
                                0 THEN
                               'Y'
                           ELSE
                               'N'
                       END
                           opencount
                  INTO t_openenfwarning
                  FROM api.relationships  r
                       JOIN query.j_investigation i ON i.jobid = r.toobjectid
                 WHERE r.fromobjectid IN x.relid
                   AND r.endpointid =
                       (api.pkg_configquery.endpointidforname(
                            'j_License',
                            'Investigation'));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_openenfwarning   := 'N';
            END;

            EXIT WHEN t_openenfwarning = 'Y';
        END LOOP;

        EXIT WHEN t_openenfwarning = 'Y';

        sitespecific.pkg_legalentity.getappforle(c.toobjectid,
                                                 NULL,
                                                 t_relatedobjids);

        FOR y IN (SELECT objectid relid FROM TABLE(t_relatedobjids))
        LOOP
            BEGIN
                SELECT CASE
                           WHEN   SUM(
                                      NVL(
                                          (SELECT SUM(
                                                      api.pkg_columnquery.numericvalue(
                                                          t.toobjectid,
                                                          'OpenStatus'))
                                             FROM api.relationships t
                                            WHERE r.toobjectid =
                                                  t.fromobjectid
                                              AND t.endpointid =
                                                  (api.pkg_configquery.endpointidforname(
                                                       'j_Investigation',
                                                       'Accusation'))),
                                          0))
                                + SUM(NVL(i.openstatus, 0)) >
                                0 THEN
                               'Y'
                           ELSE
                               'N'
                       END
                           opencount
                  INTO t_openenfwarning
                  FROM api.relationships  r
                       JOIN query.j_investigation i ON i.jobid = r.toobjectid
                 WHERE r.fromobjectid IN y.relid
                   AND r.endpointid =
                       (api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'Investigation'));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_openenfwarning   := 'N';
            END;

            EXIT WHEN t_openenfwarning = 'Y';
        END LOOP;

        EXIT WHEN t_openenfwarning = 'Y';

        sitespecific.pkg_legalentity.getp12appforle(c.toobjectid,
                                                    NULL,
                                                    t_relatedobjids);

        FOR z IN (SELECT objectid relid FROM TABLE(t_relatedobjids))
        LOOP
            BEGIN
                SELECT CASE
                           WHEN   SUM(
                                      NVL(
                                          (SELECT SUM(
                                                      api.pkg_columnquery.numericvalue(
                                                          t.toobjectid,
                                                          'OpenStatus'))
                                             FROM api.relationships t
                                            WHERE r.toobjectid =
                                                  t.fromobjectid
                                              AND t.endpointid =
                                                  (api.pkg_configquery.endpointidforname(
                                                       'j_Investigation',
                                                       'Accusation'))),
                                          0))
                                + SUM(NVL(i.openstatus, 0)) >
                                0 THEN
                               'Y'
                           ELSE
                               'N'
                       END
                           opencount
                  INTO t_openenfwarning
                  FROM api.relationships  r
                       JOIN query.j_investigation i ON i.jobid = r.toobjectid
                 WHERE r.fromobjectid IN z.relid
                   AND r.endpointid =
                       (api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'Investigation'));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_openenfwarning   := 'N';
            END;

            EXIT WHEN t_openenfwarning = 'Y';
        END LOOP;

        EXIT WHEN t_openenfwarning = 'Y';
    END LOOP;

    RETURN t_openenfwarning;
END enforcementwarning;
/
