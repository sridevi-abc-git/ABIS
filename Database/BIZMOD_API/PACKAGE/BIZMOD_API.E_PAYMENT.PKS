CREATE OR REPLACE PACKAGE BIZMOD_API.e_payment
AS
    -- **************************************************************************
    -- File:        E_PAYMENT V4.PKS
    -- Author:      Timothy J.Lord
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 04/29/2021 TJL        Package Created
    -- 12/01/2022 TJL        Added createtransmittal to spec's
    -- 01/11/2024 TJL        
    -- **************************************************************************

--    gc_transmittallimit CONSTANT NUMBER := 1000000;
--    gc_depositlimit CONSTANT NUMBER := 1000000;


    FUNCTION payfees(a_paymentmethod IN    VARCHAR2,
                     a_licensenumber IN    VARCHAR2,
                     a_licensetypecodes IN VARCHAR2,
                     a_payamount    IN     NUMBER,
                     a_payeereference IN   VARCHAR2,
                     a_payeename    IN     VARCHAR2,
                     a_paymentdate  IN     DATE,
                     a_sqlerrm         OUT VARCHAR2,
                     a_backtrace       OUT VARCHAR2)
        RETURN NUMBER;

    FUNCTION createtransmittal RETURN api.udt_objectlist;
    FUNCTION createawfpayments(a_makepayments IN NUMBER) RETURN NUMBER;

    PROCEDURE makepayment(a_licensenumber VARCHAR2, a_asofdate DATE);
    PROCEDURE makepayment(a_licensenumber    VARCHAR2,
                          a_asofdate         DATE,
                          a_error        OUT VARCHAR2);
END;
/


GRANT EXECUTE ON BIZMOD_API.E_PAYMENT TO ABC;

GRANT EXECUTE ON BIZMOD_API.E_PAYMENT TO POSSEEXTENSIONS;
