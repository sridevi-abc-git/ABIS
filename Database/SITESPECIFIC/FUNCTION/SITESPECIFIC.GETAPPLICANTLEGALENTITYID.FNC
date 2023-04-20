CREATE OR REPLACE FUNCTION SITESPECIFIC.getapplicantlegalentityid(
    a_applicationjobid NUMBER,
    a_person        CHAR,
    a_count         NUMBER)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        GETAPPLICANTLEGALENTITYID.FNC
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
    t_objectid   NUMBER;
BEGIN
    SELECT d.objectid
      INTO t_objectid
      FROM (SELECT d.objectid, ROWNUM rownumber
              FROM (  SELECT le.objectid
                        FROM api.relationships r
                             JOIN query.o_legalentity le
                                 ON le.objectid = r.toobjectid
                       WHERE r.fromobjectid = a_applicationjobid
                         AND r.endpointid IN
                                 (api.pkg_configquery.endpointidforname(
                                      'j_Application',
                                      'Applicant'),
                                  api.pkg_configquery.endpointidforname(
                                      'j_Application',
                                      'P12Applicant'))
                         AND (le.isaperson = a_person
                           OR a_person = 'X')
                    ORDER BY le.sortcolumn_stored) d) d
     WHERE d.rownumber = a_count;

    RETURN t_objectid;
END getapplicantlegalentityid;
/


GRANT EXECUTE ON SITESPECIFIC.GETAPPLICANTLEGALENTITYID TO POSSEEXTENSIONS;
