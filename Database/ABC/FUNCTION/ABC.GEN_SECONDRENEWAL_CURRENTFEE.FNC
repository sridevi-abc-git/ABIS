CREATE OR REPLACE FUNCTION ABC.gen_secondrenewal_currentfee(
    a_ltjobid      IN api.pkg_definition.udt_id,
    a_ltcode       IN VARCHAR2,
    a_feeactivity  IN VARCHAR2,
    a_expirationdate IN DATE)
    RETURN api.pkg_definition.udt_id
IS
    -- **************************************************************************
    -- File:        GEN_SECONDRENEWAL_CURRENTFEE.FNC
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
    v_feeid   api.pkg_definition.udt_id;
BEGIN
    BEGIN
        SELECT feeid
          INTO v_feeid
          FROM (  SELECT f.feeid
                    FROM api.fees f
                         JOIN
                         TABLE(
                             CAST(
                                 api.pkg_simplesearch.castableobjectsbyindex(
                                     'o_Fee',
                                     'FeeId',
                                     f.feeid) AS api.udt_objectlist)) x
                             ON 1 = 1
                         JOIN sitespecific.feeschedule_t fs
                             ON fs.objectid =
                                sitespecific.pkg_fees.getlicfeeschedulobjid(
                                    f.feeid)
                   WHERE f.jobid = a_ltjobid
                     AND fs.feeactivity = a_feeactivity
                     AND fs.licensetypecode = a_ltcode
                     AND NVL(
                             api.pkg_columnquery.datevalue(x.objectid,
                                                           'RENExpirationDate'),
                             NVL(
                                 DECODE(
                                     SUBSTR(fs.description, -1),
                                     '9', TO_DATE(               -- Final Date
                                                 TO_CHAR(      -- Day of month
                                                     LAST_DAY(
                                                            '01-'
                                                         || TO_CHAR(
                                                                LAST_DAY(
                                                                    api.pkg_columnquery.datevalue(
                                                                        a_ltjobid,
                                                                        'ExpirationDate')),
                                                                'MON')
                                                         || '-2009'),
                                                     'DD') -- End Day of month
                                              || '-'
                                              || TO_CHAR(
                                                     api.pkg_columnquery.datevalue(
                                                         a_ltjobid,
                                                         'ExpirationDate'),
                                                     'MON')           -- Month
                                              || '-2009'               -- Year
                                                        ),       -- final date
                                     'A', TO_DATE(               -- Final Date
                                                 TO_CHAR(      -- Day of month
                                                     LAST_DAY(
                                                         TO_DATE(
                                                                '01-'
                                                             || TO_CHAR(
                                                                    LAST_DAY(
                                                                        api.pkg_columnquery.datevalue(
                                                                            a_ltjobid,
                                                                            'ExpirationDate')),
                                                                    'MON')
                                                             || '-2010',
                                                             'DD-MON-YYYY')),
                                                     'DD') -- End Day of month
                                              || '-'
                                              || TO_CHAR(
                                                     api.pkg_columnquery.datevalue(
                                                         a_ltjobid,
                                                         'ExpirationDate'),
                                                     'MON')           -- Month
                                              || '-2010'               -- Year
                                                        )),       --final date
                                 LAST_DAY(SYSDATE))) =
                         a_expirationdate
                ORDER BY f.transactiondate DESC)
         WHERE ROWNUM = 1;
    END;

    RETURN v_feeid;
END gen_secondrenewal_currentfee;
/


GRANT EXECUTE ON ABC.GEN_SECONDRENEWAL_CURRENTFEE TO POSSEEXTENSIONS;
