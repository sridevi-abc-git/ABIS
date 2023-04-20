CREATE OR REPLACE PROCEDURE ABC.gen_active0222_2nd_notice(
    a_maildate      DATE DEFAULT NULL,
    a_duedate       DATE DEFAULT NULL,
    a_firstnotice   VARCHAR2 DEFAULT NULL)
AS
    -- **************************************************************************
    -- File:        GEN_ACTIVE0222_2ND_NOTICE.PRC
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
    /*_____________________________________________________________________________________________________

    GEN_ACTIVE0222_2ND_NOTICE is invoked when Accounting runs the Active 02/22 - (ABC261) Second Notice List.
    It deletes records created by the First Notice List that have AWF records indicating payment
    Accounting will review the list and then run the Active 02/22 - (ABC261) Second Notice Letters

    2/1/2018 - Copy taken from ABCPROD
    2/9/2018 - NW WIP
    _____________________________________________________________________________________________________*/


    /*_____________________________________________________________

    Pawan wrote the original script for Second Notice Letters
    _____________________________________________________________*/

    t_jobid             api.pkg_definition.udt_id;
    t_ptfeeobjectlist   api.udt_objectlist DEFAULT api.udt_objectlist();
    t_count             NUMBER;

    t_yr                VARCHAR2(2) := TO_CHAR(CURRENT_DATE, 'YY');

    t_issuedate         DATE := TO_DATE('05/31/' || t_yr, 'mm/dd/yy');

    t_transdatestart    DATE;
    t_transdateend      DATE;
BEGIN
    IF t_issuedate > CURRENT_DATE THEN
        t_yr   := TO_CHAR(ADD_MONTHS(CURRENT_DATE, -12), 'YY');
    END IF;

    t_transdatestart   := TO_DATE('07/01/' || t_yr, 'mm/dd/yy');
    t_transdateend     := CURRENT_DATE;

    UPDATE abc.active0222_rpt
       SET firstnotice   = NULL;

    COMMIT;

    FOR x IN (SELECT DISTINCT x.filenum, x.ltcode
                FROM abc.active0222_rpt x)
    LOOP
        -- get license type jobid out of filenum and LT code
        BEGIN
            SELECT x.objectid
              INTO t_jobid
              FROM TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindex(
                               'j_LicenseType',
                               'Dup_LicenseExternalFilenum',
                               x.filenum) AS api.udt_objectlist)) x
                   JOIN
                   (SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'j_LicenseType',
                                       'Dup_LicenseTypeCode',
                                       x.ltcode) AS api.udt_objectlist))) y
                       ON x.objectid = y.objectid;
        END;

        sitespecific.pkg_fees.getfeesforjob(t_jobid, NULL, t_ptfeeobjectlist);

        FOR i IN 1 .. t_ptfeeobjectlist.COUNT
        LOOP
            BEGIN
                SELECT COUNT(*)
                  INTO t_count
                  FROM query.o_fee  f
                       JOIN query.r_feelicensefeeschedule r
                           ON r.feeobjectid = f.objectid
                       JOIN query.o_feeschedule fs
                           ON fs.objectid = r.licensefeescheduleid
                 WHERE f.objectid = t_ptfeeobjectlist(i).objectid
                   AND f.feescheduletransactionfeeactiv = 'AWF'
                   AND TRUNC(f.transactiondate) BETWEEN t_transdatestart
                                                    AND t_transdateend;

                -- if AWF FEE exist, license type job is not listed
                IF t_count > 0 THEN
                    UPDATE abc.active0222_rpt
                       SET firstnotice   = 'X'
                     WHERE filenum = x.filenum
                       AND ltcode = x.ltcode;
                END IF;
            END;
        END LOOP;

        COMMIT;
    END LOOP;
END;
/


GRANT EXECUTE ON ABC.GEN_ACTIVE0222_2ND_NOTICE TO PUBLIC;
