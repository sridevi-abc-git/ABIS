CREATE OR REPLACE PROCEDURE ABC.tl_classlist(
    p_objectid     IN     api.pkg_definition.udt_id,
    p_district     IN     VARCHAR2,
    p_startdate    IN     DATE,
    p_enddate      IN     DATE,
    p_classlist       OUT SYS_REFCURSOR)
IS
    -- ****************************************************************************
    -- File:        TL_CLASSLIST.PRC
    -- Author:      Timothy J. Lord
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 10/23/2016 TJL 10823 Added number of students attending class after the class
    --                      was given
    -- ****************************************************************************

BEGIN
    OPEN p_classlist FOR
          SELECT district,
                 location,
                 TO_CHAR(trainingdate, 'MM/DD/YYYY')
                     trainingdate,
                 classcancelled,
                 classfull,
                 classcancelled,
                 classsize,
                 studentsregistered,
                 spotsavailable,
                 CASE
                     WHEN TO_DATE(TO_CHAR(trainingdate, 'MM/DD/YYYY'),
                                  'MM/DD/YYYY') <
                          TRUNC(SYSDATE + 1) THEN
                         numberofstudentspassed + numberofstudentsfailed
                     ELSE
                         NULL
                 END
                     studentsattended,
                 classtimeexpression,
                 isactive,
                 objectid
            FROM query.o_tl_leadclassinfo
           WHERE objectid IN
                     (SELECT objectid
                        FROM query.o_tl_leadclassinfo
                       WHERE trainingdate BETWEEN TRUNC(
                                                      NVL(p_startdate,
                                                          trainingdate))
                                              AND TRUNC(
                                                      NVL(p_enddate,
                                                          trainingdate))
                         AND objectid = NVL(p_objectid, objectid)
                         AND district = NVL(p_district, district))
        ORDER BY district, TO_DATE(trainingdate, 'MM/DD/YYYY');
EXCEPTION
    WHEN OTHERS THEN
        -- Consider logging the error and then re-raise
        RAISE;
END tl_classlist;
/


GRANT EXECUTE ON ABC.TL_CLASSLIST TO POSSEEXTENSIONS;
