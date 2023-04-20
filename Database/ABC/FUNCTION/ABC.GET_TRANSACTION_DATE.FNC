CREATE OR REPLACE FUNCTION ABC.get_transaction_date(p_feeid        IN NUMBER,
                                                    p_amount       IN NUMBER)
    RETURN DATE
IS
    -- **************************************************************************
    -- File:        GET_TRANSACTION_DATE.FNC
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
    a_transaction_date   DATE;
BEGIN
    BEGIN
        /* --this is old sql 08/3/2011 bee
        select distinct nvl(TA.TRANSACTIONDATE,sysdate)
        into a_transaction_date
        from API.FEETRANSACTIONS ta
        join API.PAYMENTTRANSACTIONS pt on PT.TRANSACTIONID =TA.TRANSACTIONID
        where TA.FEEID = p_feeid; */

        --this is the new one suggested by Josh 8/3/2011 Bee
        --joined api.fees.  this makes sense.  Bee
        SELECT DISTINCT NVL(f.transactiondate, SYSDATE)
          INTO a_transaction_date
          FROM api.fees  f
               JOIN api.feetransactions ta ON ta.feeid = f.feeid
               JOIN api.paymenttransactions pt
                   ON pt.transactionid = ta.transactionid
         WHERE ta.feeid = p_feeid;
    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            SELECT DISTINCT NVL(ta.transactiondate, SYSDATE)
              INTO a_transaction_date
              FROM api.feetransactions  ta
                   JOIN api.paymenttransactions pt
                       ON pt.transactionid = ta.transactionid
             WHERE ta.feeid = p_feeid
               AND ta.amount = p_amount * -1;
        WHEN OTHERS THEN
            a_transaction_date   := TRUNC(SYSDATE);
            NULL;
    END;

    RETURN a_transaction_date;
END get_transaction_date;
/


GRANT EXECUTE ON ABC.GET_TRANSACTION_DATE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GET_TRANSACTION_DATE TO PUBLIC;
