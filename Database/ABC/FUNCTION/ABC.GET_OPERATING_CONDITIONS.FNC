CREATE OR REPLACE FUNCTION ABC.get_operating_conditions(p_jobid INTEGER)
    RETURN XMLTYPE
IS
    -- **************************************************************************
    -- File:        GET_OPERATING_CONDITIONS.FNC
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
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************

    -- The LQS displays conditions for Applications that were received after cutoff date and after they are issued
    k_cutoff    CONSTANT DATE := TO_DATE('05/01/2017', 'MM/DD/YYYY'); -- Production Date
    --  K_CUTOFF  CONSTANT date := TO_DATE('01/01/2016','MM/DD/YYYY');  -- For testing

    -- If there are Operating Conditions for licenses before cutoff date, we display this message and offer this link
    k_link      CONSTANT VARCHAR2(200)
                             := 'http://www.abc.ca.gov/forms/ABC-586.pdf' ;
    link_text   CONSTANT VARCHAR2(200)
        := '*Operating Restrictions exist. For more information, please see our Guidelines for Access to Records.' ;

    l_xml                XMLTYPE;
BEGIN
    WITH
        lic_app
        AS
            (SELECT a.objectid--  , ( SELECT COPIESMAILED FROM QUERY.J_APPLICATION A2 WHERE A2.JOBID=A.OBJECTID ) COPIESMAILED
                              , copiesmailed
               FROM mart.licensetype  lt
                    LEFT JOIN mart.application a
                        ON a.licensenumber = lt.licensenumber
                       AND a.statusname = 'ISSUED'
              WHERE lt.cond7 = 'Y'
                AND lt.licensejobid = p_jobid)             -- END WITH LIC_APP
                                              ,
        cond
        AS
            (  SELECT MAX(ac.sort)
                          sort,
                      CASE
                          --      WHEN COPIESMAILED < K_CUTOFF
                          WHEN copiesmailed IS NULL
                            OR copiesmailed < k_cutoff THEN
                              link_text
                          ELSE
                              ac.conditiontext
                      END
                          conditiontext
                 FROM lic_app la
                      LEFT JOIN mart.applicationconditions ac
                          ON ac.applicationjobid = la.objectid
                      --    JOIN MART.CONDITIONS C ON C.OBJECTID = AC.CONDITIONOBJECTID AND C.ISCONDITION='Y'
                      LEFT JOIN mart.conditions c
                          ON c.objectid = ac.conditionobjectid
                         AND c.iscondition = 'Y'
             GROUP BY CASE
                          --    WHEN COPIESMAILED < K_CUTOFF
                          WHEN copiesmailed IS NULL
                            OR copiesmailed < k_cutoff THEN
                              link_text
                          ELSE
                              ac.conditiontext
                      END)                                    -- END WITH COND
    SELECT XMLAGG(
               XMLELEMENT("OPERATING_RESTRICTION",
                          xmlattributes(k_link AS "LINK"),
                          conditiontext))
               conditions
      INTO l_xml
      FROM cond c;

    RETURN l_xml;
END get_operating_conditions;
/
