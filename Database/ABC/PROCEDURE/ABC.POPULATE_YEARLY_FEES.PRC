CREATE OR REPLACE PROCEDURE ABC.populate_yearly_fees
IS
    -- **************************************************************************
    -- File:        POPULATE_YEARLY_FEES.PRC
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
    CURSOR s_cur
    IS
        (SELECT SUBSTR(a.licensetypenumberconcat, 1, 2)
                    licensetypecode,
                a.licensetypenames,
                a.licensenumber,
                a.applicationnumberandtype,
                NVL(fe.applicationnumber, fe.licensenumber)
                    licenseorappnumber,
                fe.licensetypecodeexpression,
                fe.jobid,
                feeactivity,
                fe.feescheduletransactioncode,
                fe.glaccountdescription,
                fe.licensetypecode
                    o_licensetypecode,
                f.transactiondate,
                f.amount,
                f.adjustedamount,
                f.adjustedtaxes,
                f.paidamount * -1
                    paidamount
           FROM api.fees  f
                JOIN
                TABLE(
                    CAST(
                        api.pkg_simplesearch.castableobjectsbyindex('o_Fee',
                                                                    'FeeId',
                                                                    f.feeid) AS api.udt_objectlist))
                x
                    ON 1 = 1
                JOIN query.o_fee fe ON fe.objectid = x.objectid
                JOIN sitespecific.feeschedule_t t
                    ON t.objectid =
                       sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                JOIN query.j_application a ON a.jobid = f.jobid
          WHERE f.transactiondate BETWEEN '01-JUL-16' AND '30-JUN-17');

    TYPE fetch_array IS TABLE OF s_cur%ROWTYPE;

    s_array   fetch_array;
BEGIN
    OPEN s_cur;

    LOOP
        FETCH s_cur BULK COLLECT INTO s_array LIMIT 10;

        FORALL i IN 1 .. s_array.COUNT
            INSERT INTO fees_yearly
            VALUES s_array(i);

        EXIT WHEN s_cur%NOTFOUND;
    END LOOP;

    CLOSE s_cur;

    COMMIT;
END;
/
