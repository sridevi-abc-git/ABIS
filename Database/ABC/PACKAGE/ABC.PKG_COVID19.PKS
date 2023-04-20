CREATE OR REPLACE PACKAGE ABC.pkg_covid19
AS
    -- **************************************************************************
    -- File:        PKG_COVID19.PKS
    -- Author:      Timothy J.Lord
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 02/03/2021 TJL        Package Created
    -- **************************************************************************
    PROCEDURE upd_cert(a_start_date IN DATE DEFAULT NULL, a_end_date IN DATE DEFAULT TRUNC(SYSDATE));

    PROCEDURE upd_cert_renewal(a_start_date IN DATE, a_end_date IN DATE, a_batchseq IN NUMBER DEFAULT NULL);

    PROCEDURE upd_cert_penalty(a_penalty      IN VARCHAR2,
                               a_start_date   IN DATE,
                               a_end_date     IN DATE,
                               a_batchseq     IN NUMBER DEFAULT NULL);

    PROCEDURE upd_cert_payment(a_batchseq IN NUMBER DEFAULT NULL);

    PROCEDURE upd_cert_license_issued(a_batchseq IN NUMBER DEFAULT NULL);
    
END;
/
