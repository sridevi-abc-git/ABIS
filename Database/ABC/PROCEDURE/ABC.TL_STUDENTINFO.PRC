CREATE OR REPLACE PROCEDURE ABC.tl_studentinfo(
    p_studentobjectid IN  NUMBER,
    p_data            OUT SYS_REFCURSOR)
IS
    -- **************************************************************************
    -- File:        TL_STUDENTINFO.PRC
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
    OPEN p_data FOR
        SELECT s.objectid,
               s.studentname,
               s.emailaddress,
               s.phonenumber,
               s.confirmationnumber,
               s.iscompleteregistration,
               s.isstandby,
               s.passfail,
               s.passed,
               s.failed,
               sc.status,
               sl.processstatus,
               TO_CHAR(sc.processdate, 'MM/DD/YYYY HH:MI:SS PM')
                   processdate,
               c.objectid
                   classobjectid,
               c.district,
               c.location,
               TO_CHAR(c.trainingdate, 'MM/DD/YYYY')
                   trainingdate,
               c.classtimeexpression,
               e.emailid
          FROM query.o_tl_leadclassinfo  c
               JOIN query.r_leadclassregistration r
                   ON (c.objectid = r.leadclassid)
               JOIN query.o_tl_studentregistration s
                   ON (r.studentregistrationid = s.objectid)
               LEFT OUTER JOIN scheduler.sysschedule sc
                   ON (s.schedulekey = sc.schedulekey)
               LEFT OUTER JOIN scheduler.sysschedulelog sl
                   ON (s.schedulekey = sl.schedulekey)
               LEFT OUTER JOIN query.r_studentregistrationprintlead x
                   ON x.studentregistration = s.objectid
               LEFT OUTER JOIN extension.emails e
                   ON e.relatedobjectid = x.printleadcertificate
         WHERE (sl.schedulelogkey IS NULL
             OR sl.schedulelogkey = (SELECT MAX(schedulelogkey)
                                       FROM scheduler.sysschedulelog sl2
                                      WHERE sl2.schedulekey = s.schedulekey))
           AND (x.printleadcertificate IS NULL
             OR x.printleadcertificate =
                (SELECT MAX(x2.printleadcertificate)
                   FROM query.r_studentregistrationprintlead x2
                  WHERE x2.studentregistration = s.objectid))
           AND s.objectid = p_studentobjectid;
END;
/


GRANT EXECUTE ON ABC.TL_STUDENTINFO TO POSSEEXTENSIONS;
