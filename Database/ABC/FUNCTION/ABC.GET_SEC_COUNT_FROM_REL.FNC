CREATE OR REPLACE FUNCTION ABC.get_sec_count_from_rel(p_jobid NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GET_SEC_COUNT_FROM_REL.FNC
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
    --
    secs_counts   VARCHAR2(4000);

    CURSOR get_recs
    IS
        (SELECT ROWNUM, av.sections
           FROM query.j_accusation  a
                JOIN query.r_accusationviolation av
                    ON av.accusationjobid = a.jobid
          WHERE a.jobid = p_jobid);
BEGIN
    FOR x IN get_recs
    LOOP
        IF x.ROWNUM = 1 THEN
            secs_counts   := x.sections;
        ELSE
            secs_counts   := secs_counts || ', ' || x.sections;
        END IF;
    END LOOP;

    RETURN (secs_counts);
END get_sec_count_from_rel;
/


GRANT EXECUTE ON ABC.GET_SEC_COUNT_FROM_REL TO POSSEEXTENSIONS;
