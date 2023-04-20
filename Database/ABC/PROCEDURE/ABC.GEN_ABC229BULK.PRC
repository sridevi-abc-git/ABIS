CREATE OR REPLACE PROCEDURE ABC.gen_abc229bulk(
    a_objectid      api.pkg_definition.udt_id)
AS
    -- **************************************************************************
    -- File:        GEN_ABC229BULK.PRC
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

    t_check   VARCHAR2(1);
BEGIN
    -- check record exist
    BEGIN
        SELECT 'x'
          INTO t_check
          FROM query.o_abc229bulk  o
               LEFT OUTER JOIN query.r_abc229bulkinvestigatorlr r
                   ON r.abc229bulkobjectid = o.objectid
         WHERE o.objectid = a_objectid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            api.pkg_errors.raiseerror(
                -20000,
                'No Data Found on Query.o_ABC229Bulk table.');
    END;

    -- delete ABC.ABC229BULK_T records
    DELETE FROM abc.abc229bulk_t commit;

    -- delete ABC.ABC229BULK_DET_T records
    DELETE FROM abc.abc229bulk_det_t commit;

    --loop through all Application Investigation records
    FOR c_appinv
        IN (  SELECT DISTINCT b.objectid,
                              a.jobid,
                              a.primarylicensee firstowner,
                              a.premaddress1line premises,
                              a.premcensustract censustract,
                              a.primarydba     pdba,
                              a.licensenumber  licno,
                              a.copiesmailed   copiesmailed
                FROM query.j_application a
                     JOIN api.jobstatuses js
                         ON js.jobtypeid = a.jobtypeid
                        AND js.statusid = a.statusid
                        AND (js.statustype = 'O'
                          OR js.statustype = 'I')
                     JOIN query.p_assignappinvestigation ai
                         ON ai.jobid = a.jobid
                     LEFT OUTER JOIN query.p_conductappinvestigation ci
                         ON ci.jobid = a.jobid
                     LEFT OUTER JOIN query.r_applicationinvestigationlog al
                         ON al.applicationjobid = a.jobid
                     LEFT OUTER JOIN query.l_lruserlog ul
                         ON ul.objectid = al.investigationuserlogid
                     JOIN query.o_abc229bulk b
                         ON ai.licensingrep =
                            NVL(b.investigatorlr, ai.licensingrep)
                        AND TRUNC(ai.createddate) BETWEEN NVL(
                                                              b.createddatefrom,
                                                              TRUNC(
                                                                  ai.createddate))
                                                      AND NVL(
                                                              b.createddateto,
                                                              TRUNC(
                                                                  ai.createddate))
                        AND ((TRUNC(ci.datecompleted) >=
                              NVL(b.completeddatefrom, TRUNC(ci.datecompleted))
                          AND TRUNC(ci.datecompleted) <=
                              NVL(b.completeddateto, TRUNC(ci.datecompleted)))
                          OR (ci.datecompleted IS NULL
                          AND b.completeddatefrom IS NULL
                          AND b.completeddateto IS NULL))
                        AND (TRUNC(ul.logdate) >= TRUNC(b.commentsdate)
                          OR b.commentsdate IS NULL)
                        AND ((b.activeonly = 'N'
                          AND ci.datecompleted IS NOT NULL)
                          OR (b.activeonly = 'Y'
                          AND ci.datecompleted IS NULL
                          AND ci.createddate IS NOT NULL))
               WHERE b.objectid = a_objectid
            ORDER BY licno)
    LOOP
        -- insert into ABC.ABC229BULK_T
        INSERT INTO abc.abc229bulk_t(objectid,
                                     jobid,
                                     firstowner,
                                     premises,
                                     censustract,
                                     pdba,
                                     licno,
                                     copiesmailed)
             VALUES (c_appinv.objectid,
                     c_appinv.jobid,
                     c_appinv.firstowner,
                     c_appinv.premises,
                     c_appinv.censustract,
                     c_appinv.pdba,
                     c_appinv.licno,
                     c_appinv.copiesmailed);

        -- insert into ABC.ABC229BULK_DET_T
        INSERT INTO abc.abc229bulk_det_t
              SELECT c_appinv.objectid,
                     a.jobid,
                     ul.logdate eventdate,
                     ul.comments summary
                FROM query.j_application a
                     JOIN query.r_applicationinvestigationlog ai
                         ON ai.applicationjobid = a.jobid
                     JOIN query.l_lruserlog ul
                         ON ul.userlogid = ai.investigationuserlogid
               WHERE a.jobid = c_appinv.jobid
            ORDER BY eventdate DESC;
    END LOOP;
END gen_abc229bulk;
/


GRANT EXECUTE ON ABC.GEN_ABC229BULK TO POSSEEXTENSIONS;
