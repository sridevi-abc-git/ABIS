CREATE OR REPLACE PROCEDURE ABC.tl_studentsearch(
    a_studentname  IN     VARCHAR2,
    a_emailaddress IN     VARCHAR2,
    a_confirmationnumber IN NUMBER,
    a_phonenumber  IN     VARCHAR2,
    a_studentdata     OUT SYS_REFCURSOR)
IS
    -- **************************************************************************
    -- File:        TL_STUDENTSEARCH.PRC
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
    OPEN a_studentdata FOR
          SELECT s.objectid,
                 s.studentname,
                 s.emailaddress,
                 s.attended,
                 s.passed,
                 s.confirmationnumber,
                 s.phonenumber,
                 c.objectid                          classobjectid,
                 c.district,
                 c.location,
                 TO_CHAR(c.trainingdate, 'MM/DD/YYYY') trainingdate,
                 c.classtimeexpression
            FROM query.o_tl_leadclassinfo c
                 JOIN query.r_leadclassregistration r
                     ON (c.objectid = r.leadclassid)
                 JOIN query.o_tl_studentregistration s
                     ON (r.studentregistrationid = s.objectid)
           WHERE s.objectid IN
                     (SELECT objectid
                        FROM query.o_tl_studentregistration s2
                       WHERE UPPER(s2.studentname) LIKE
                                    '%'
                                 || UPPER(NVL(a_studentname, s2.studentname))
                                 || '%'
                         AND UPPER(s2.emailaddress) LIKE
                                    '%'
                                 || UPPER(NVL(a_emailaddress, s2.emailaddress))
                                 || '%'
                         AND s2.confirmationnumber =
                             NVL(a_confirmationnumber, confirmationnumber)
                         AND NVL(s2.phonenumber, '*') =
                             NVL(a_phonenumber, NVL(s2.phonenumber, '*')))
             AND c.classcancelled = 'N'
        ORDER BY studentname, s.confirmationnumber DESC;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END tl_studentsearch;
/


GRANT EXECUTE ON ABC.TL_STUDENTSEARCH TO POSSEEXTENSIONS;
