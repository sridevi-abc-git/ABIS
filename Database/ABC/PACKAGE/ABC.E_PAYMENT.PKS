CREATE OR REPLACE PACKAGE ABC.e_payment
AS
    -- **************************************************************************
    -- File:        E_PAYMENT.PKS
    -- Author:      Timothy J.Lord
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 04/29/2021 TJL        Package Created
    -- **************************************************************************

    gc_transmittallimit   CONSTANT NUMBER := 1000000;
    gc_depositlimit       CONSTANT NUMBER := 1000000;


    PROCEDURE processpayments(a_paymentdate IN DATE DEFAULT SYSDATE - 1, a_paymentonly IN VARCHAR2 DEFAULT 'N');
END;
/
