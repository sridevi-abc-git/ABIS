CREATE OR REPLACE PROCEDURE ABC.pastcurrentdiscplanryactions--( p_JobId INTEGER, p_xml OUT XMLTYPE )
                                                            (
    p_jobid            INTEGER,
    p_xml          OUT CLOB)
IS
    -- **************************************************************************
    -- File:        PASTCURRENTDISCPLANRYACTIONS.PRC
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
    -- 08/21/2018 TJL         Initial Check-in
    -- **************************************************************************
BEGIN
    WITH
        accusations
        AS
            (SELECT a.objectid  allegations_eid,
                    licensejobid,
                    a.regnumber reg_number,
                    av.sections section
               FROM mart.accusation  a
                    LEFT JOIN mart.accusationviolation av
                        ON av.accusationobjectid = a.objectid
              WHERE a.statusname IN ('CLOSED', 'DISMSD')),
        proceedings
        AS
            (SELECT DISTINCT
                    a.objectid,
                    UPPER(
                        DECODE(a.statusname,
                               'DISMSD', 'Dismissed',
                               d.outcome))
                        decision,
                    (DECODE(a.statusname, 'DISMSD', NULL, d.suspensiondays))
                        suspension_days,
                    d.stayeddays
                        stayed_days,
                    a.statusname
                        proceeding_status,
                    (SELECT p1.poicfee
                       FROM mart.processpoic p1
                      WHERE p1.objectid = p.objectid)
                        poic_fee,
                    NVL(TO_CHAR(psr.postingdate, 'DD-MON-YYYY'),
                        TO_CHAR(d.suspensionstartdate, 'DD-MON-YYYY'))
                        suspension_start_date,
                    NVL(
                        DECODE(
                            psr.indefinitesuspension,
                            'Y', 'INDEFINITE SUSPENSION',
                            TO_CHAR(
                                (SELECT MAX(
                                              psr1.numberofsuspensiondays
                                            + psr1.postingdate)
                                   FROM mart.postsuspensionrevocation psr1
                                  WHERE psr1.jobid = a.objectid),
                                'DD-MON-YYYY')),
                        TO_CHAR(d.suspensionenddate, 'DD-MON-YYYY'))
                        suspension_end_date
               FROM mart.accusation  a
                    JOIN query.p_executetermsofdecision d
                        ON d.objectid =
                           (SELECT MAX(d1.objectid)
                              FROM mart.executetermsofdecision d1
                             WHERE d1.jobid = a.objectid
                               AND d1.outcome IS NOT NULL)
                    LEFT OUTER JOIN
                    (  SELECT MAX(r1.objectid) objectid, r1.jobid
                         FROM mart.postsuspensionrevocation r1
                     GROUP BY r1.jobid) r
                        ON r.jobid = a.objectid
                    LEFT OUTER JOIN
                    (  SELECT MAX(p1.objectid) objectid, p1.jobid
                         FROM mart.processpoic p1
                     GROUP BY p1.jobid) p
                        ON p.jobid = a.objectid
                    LEFT OUTER JOIN mart.postsuspensionrevocation psr
                        ON psr.jobid = a.objectid)
      SELECT XMLELEMENT("DISCIPLINARY_HISTORY",
                        XMLAGG(XMLELEMENT("REGISTRATION",
                                          XMLFOREST(a.reg_number--        , XMLAGG(XMLELEMENT("SECTION",A.SECTION)) SECTIONS
                                                                ,
                                                    a.section,
                                                    p.proceeding_status,
                                                    p.decision,
                                                    p.suspension_days,
                                                    p.stayed_days,
                                                    p.poic_fee,
                                                    p.suspension_start_date,
                                                    p.suspension_end_date)))).getclobval()
        INTO p_xml
        FROM accusations a
             LEFT JOIN proceedings p ON p.objectid = a.allegations_eid
       WHERE a.licensejobid = p_jobid                              -- 19186238
    /*
    GROUP BY
            A.REG_NUMBER
          , P.DECISION
          , A.REG_NUMBER
          , P.PROCEEDING_STATUS
          , P.DECISION
          , P.SUSPENSION_DAYS
          , P.STAYED_DAYS
          , P.POIC_FEE
          , P.SUSPENSION_START_DATE
          , P.SUSPENSION_END_DATE
          , A.SECTION
    */
    ORDER BY a.reg_number, a.section;
END pastcurrentdiscplanryactions;

----------------------------------------------------------------------
-- Test Script
----------------------------------------------------------------------
-- SET SERVEROUTPUT ON
/
