CREATE OR REPLACE PROCEDURE BIZMOD_API.updatepaymentprocessedtable
IS
    -- ****************************************************************************
    -- File:        UPDATEPAYMENTPROCESSEDTABLE.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --      this procedure call is only temporaray until the e_payments_processed_t
    --        table is updated from the reports that indicate that credit card
    --        payments have cleared
    -- History:
    -------------------------------------------------------------------------------
    --    Date           Ticket     Comment
    --  02/27/2023 TJL            Initial Function Created
    -- ****************************************************************************
    t_msg          VARCHAR2(4000);
    t_results      CLOB;
    t_packet       CLOB;
    t_count        NUMBER := 0;
BEGIN
    INSERT INTO bizmod_api.e_payments_processed_t(licensenumber,
                                                  siteid,
                                                  sitename,
                                                  --                                   transactionid,
                                                  --                                   paymentid,
                                                  appid,
                                                  transactionresult,
                                                  paymentresult,
                                                  paymenttimestamp,
                                                  paymentamount,
                                                  reference,
                                                  processor,
                                                  paymtattemptamount,
                                                  paymtprocessedamount,
                                                  usesconvfee,
                                                  fullname,
                                                  paymentmedium,
                                                  confirmationnumber,
                                                  paymenttype,
                                                  postdateedt,
                                                  exporttimestamp)
          SELECT p.licensenumber, -- LicenseNumber
                 30057, -- 'SiteID,'
                 'State of Califorina', -- 'SiteName,'
                 --             p.seq, -- 'TransactionID,'
                 --             p.paymentobjectid, -- 'PaymentID,'
                 31540, -- 'AppID,'
                 'Settled', -- 'Transaction Result,'
                 'Settled', -- 'Payment Result,'
                 p.datepaid, -- 'Payment Timestamp,'
                 SUM(p.amountpaid), -- 'Payment Amount,'
                 '"="' || p.licensenumber || ', "' || p.payeename || '""', -- 'Reference,'
                 'NFTF', -- 'Processor,'
                 SUM(p.amountpaid), -- 'Paymt Attempt Amount,'
                 SUM(p.amountpaid), -- 'Paymt Processed Amount,'
                 CASE p.paymentmethod WHEN 'Credit Card' THEN 'Y' ELSE 'N' END, -- 'Uses Conv. Fee,'
                 p.payeename, -- full name
                 p.paymentmethod, -- PaymentMedium
                 p.confirmationid, -- 'Confirmation #,'
                 'Primary', -- 'Payment Type
                 p.datepaid, -- 'Post Date(EDT),'
                 p.datepaid --); -- 'Export Timestamp'
            FROM bizmod_api.e_payments_t p
                 LEFT OUTER JOIN bizmod_api.e_payments_processed_t fd
                     ON (p.licensenumber = fd.licensenumber)
           WHERE p.transmittalbatch IS NULL
             AND fd.licensenumber IS NULL
        GROUP BY p.licensenumber,
                 p.datepaid,
                 p.payeename,
                 p.paymentmethod,
                 p.confirmationid;
    COMMIT;

    bizmod_api.createjob(
        a_procedure => 'PROCESSPAYMENTS',
        a_description => 'Process Payments',
        a_argument1 => NULL);

EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
        NULL;
    WHEN OTHERS
    THEN
        -- Consider logging the error and then re-raise
        RAISE;
END updatepaymentprocessedtable;
/


GRANT EXECUTE ON BIZMOD_API.UPDATEPAYMENTPROCESSEDTABLE TO ABC;

GRANT EXECUTE ON BIZMOD_API.UPDATEPAYMENTPROCESSEDTABLE TO POSSEEXTENSIONS;
