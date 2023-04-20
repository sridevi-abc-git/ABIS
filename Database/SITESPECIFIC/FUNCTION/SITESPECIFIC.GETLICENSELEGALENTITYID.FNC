CREATE OR REPLACE FUNCTION SITESPECIFIC.getlicenselegalentityid(
    a_licensejobid  NUMBER,
    a_person        CHAR,
    a_count         NUMBER)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        GETLICENSELEGALENTITYID.FNC
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
    t_objectid   NUMBER(9);
BEGIN
    SELECT d.objectid
      INTO t_objectid
      FROM (SELECT d.objectid, ROWNUM rownumber
              FROM (  SELECT le.objectid
                        FROM api.relationships r
                             JOIN query.o_legalentity le
                                 ON le.objectid = r.toobjectid
                       WHERE r.fromobjectid = a_licensejobid
                         AND r.endpointid IN
                                 (api.pkg_configquery.endpointidforname(
                                      'j_License',
                                      'LicenseeLegalEntity'),
                                  api.pkg_configquery.endpointidforname(
                                      'j_License',
                                      'P12Licensee'))
                         AND (le.isaperson = a_person
                           OR a_person = 'X')
                    ORDER BY le.sortcolumn_stored) d) d
     WHERE d.rownumber = a_count;

    RETURN t_objectid;
END getlicenselegalentityid;
/


GRANT EXECUTE ON SITESPECIFIC.GETLICENSELEGALENTITYID TO POSSEEXTENSIONS;
