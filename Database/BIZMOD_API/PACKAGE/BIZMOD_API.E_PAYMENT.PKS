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
    --          04/29/2021 TJL             Package Created
    --          12/01/2022 TJL             Added createtransmittal to spec's
    --          01/11/2024 TJL  BIZ-14091  Removed createtransmittal and createawfpayments
    --                                       from package.
    --     6.0  04/24/2024 TJL  BIZ-15142  Change prototypes procedures and functions
    -- **************************************************************************


    FUNCTION payfees(a_feeobjidlst  IN     api.udt_objectlist,
                     a_paymentmethod IN    VARCHAR2,
                     a_payeereference IN   VARCHAR2,
                     a_payeename    IN     VARCHAR2,
                     a_paymentdate  IN     DATE,
                     a_jobid        IN      NUMBER,
                     a_sqlerrm         OUT VARCHAR2,
                     a_backtrace       OUT VARCHAR2)
        RETURN NUMBER;

    PROCEDURE makepayment(a_confirmationid IN VARCHAR2);
    PROCEDURE makepayment(a_confirmationid IN  VARCHAR2,
                          a_error          OUT VARCHAR2);
END;
/


GRANT EXECUTE ON BIZMOD_API.E_PAYMENT TO ABC;

GRANT EXECUTE ON BIZMOD_API.E_PAYMENT TO POSSEEXTENSIONS;
