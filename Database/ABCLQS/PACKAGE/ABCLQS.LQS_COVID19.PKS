CREATE OR REPLACE PACKAGE ABCLQS.lqs_covid19
AS
    -- **************************************************************************
    -- File:        LQS_COVID19.PKS
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
    PROCEDURE covid19(a_parameters IN XMLTYPE, a_reportdata OUT BLOB, a_message OUT VARCHAR);

    PROCEDURE get_fees(a_parameters IN XMLTYPE, a_reportdata OUT BLOB, a_message OUT VARCHAR);

    PROCEDURE upd_cert(a_parameters IN XMLTYPE, a_reportdata OUT BLOB, a_message OUT VARCHAR);

END;
/
