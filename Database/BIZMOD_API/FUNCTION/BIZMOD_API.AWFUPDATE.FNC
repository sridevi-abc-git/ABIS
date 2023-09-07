CREATE OR REPLACE FUNCTION BIZMOD_API.awfupdate(a_packet IN CLOB, a_seq IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.AWFUPDATE.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :    This function is called thru the eservices API to figure out
    --              AWF amount for a selected license number.  It will return
    --              the calculated amount and save the AWF information in the
    --              AWF_T table
    --
    -- History:
    -------------------------------------------------------------------------------
    --  Ver:       Date           Ticket     Comment
    --          06/08/2022 TJL  BIZ-      Initial Function Created
    --          02/17/2023 TJL            Converted to using JSON objects.
    --   2.0    07/25/2023  TJL  BIZ-12090  Added updating feerequired field in awf table (new field)
    --   2.0    07/27/2023  TJL  BIZ-12143  Added updating updateddate field in awf table (new field)
    --   2.1    07/31/2023  TJL  BIZ-12090  Added returning 'FEEREQUIRED' in return packet
    --   3.0    09/07/2023  TJL  BIZ-12530  Removed additional million gallons limit
    -- ****************************************************************************
    t_results      CLOB;
    t_licensenumber VARCHAR2(10);
    t_licensetypejobid NUMBER;
    t_renfeeid     NUMBER;
    t_gallonage    NUMBER;
    t_amount       NUMBER;
    t_renamount    NUMBER;
    t_feeamount    NUMBER;
    t_scheduleid   NUMBER;

    t_feeactivitytype VARCHAR2(20);
    t_ltcode       VARCHAR2(3);
    t_awfdate      DATE;
    t_gallonagerange VARCHAR2(100);
    t_additionalmilliongallons NUMBER;
    t_awffee       NUMBER;
    t_justification VARCHAR2(1000);
    t_adjustedamount NUMBER;
    t_feerequired  NUMBER;
    t_paidamount   NUMBER;

    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000);
-- ****************************************************************************
-- ****************************************************************************
--  Main Function Body
-- ****************************************************************************
-- ****************************************************************************
BEGIN
    SELECT feeid,
           gallonage,
           licensenumber,
           justification
      INTO t_renfeeid,
           t_gallonage,
           t_licensenumber,
           t_justification
      FROM JSON_TABLE(
               a_packet,
               '$'
               COLUMNS(
                   packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                   NESTED PATH '$.DATA[*]'
                       COLUMNS(
                           feeid NUMBER PATH '$.FEEID',
                           licensenumber VARCHAR2(1000)
                               PATH '$.LICENSENUMBER',
                           gallonage NUMBER PATH '$.GALLONAGE',
                           justification VARCHAR2(1000)
                               PATH '$.JUSTIFICATION')));

    -- from gallonage entered figure out codes
    t_gallonagerange :=
        CASE
            WHEN t_gallonage BETWEEN 0 AND 5000 THEN '0 TO 5K'
            WHEN t_gallonage BETWEEN 5001 AND 20000 THEN '5K TO 20K'
            WHEN t_gallonage BETWEEN 20001 AND 100000 THEN '20K TO 100K'
            WHEN t_gallonage BETWEEN 100001 AND 200000 THEN '100K TO 200K'
            ELSE '200K TO 1M'
        END;

    t_additionalmilliongallons :=
        CASE
            WHEN t_gallonage > 0 THEN FLOOR((t_gallonage - 1) / 1000000)
            ELSE 0
        END;

--    IF (t_additionalmilliongallons > 99)
--    THEN
--        RAISE VALUE_ERROR;
--    END IF;

    -- get current fee info
    SELECT a.renactivity,
           a.licensetypecode,
           a.renewalamountpaid,
           a.awfdate,
           a.licensetypejobid
      INTO t_feeactivitytype,
           t_ltcode,
           t_renamount,
           t_awfdate,
           t_licensetypejobid
      FROM awf_t a
     WHERE a.renfeeid = t_renfeeid;

    -- get new fee amount for new gallonage amount
    sitespecific."PKG_FEES".getltfeeamount(
        a_jobid     => NULL,
        a_effectivedate => t_awfdate,
        a_feeactivitytype => SUBSTR(t_feeactivitytype, 1, 3),
        a_otherfeecode => NULL,
        a_ltcode    => t_ltcode,
        a_gallonagerange => t_gallonagerange,
        a_additionalmilliongallons => t_additionalmilliongallons,
        a_numberofmonthslicensed => NULL,
        a_populationrange => NULL,
        a_tier      => NULL,
        a_feetype   => 'P',
        a_ltcount   => 0,
        a_asofdate  => SYSDATE,
        a_feeamount => t_feerequired,
        a_licensefeescheduleid => t_scheduleid);

    -- get difference to figure out AWF fee
    t_awffee := t_feerequired + t_renamount;

    -- update abc261 table to new information
    UPDATE awf_t a
       SET a.newgallonage = t_gallonagerange,
           a.newaddionalgallonage = t_additionalmilliongallons,
           a.awffeeamount = t_awffee,
           a.gallonage261 = t_gallonage,
           a.justification = t_justification,
           a.feerequired = t_feerequired,
           a.submitteddate = SYSDATE
     WHERE a.renfeeid = t_renfeeid;

    COMMIT;

    -- build return packet
    t_results :=
        json_object(
            'PACKET_TYPE' VALUE 'AWFUPDATERESULTS',
            'DATA' VALUE
                json_object('LICENSENUMBER' VALUE t_licensenumber,
                            'AMOUNTOWED' VALUE t_awffee,
                            'FEEREQUIRED' VALUE t_feerequired));
    RETURN t_results;
EXCEPTION
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

        UPDATE bizmod_api.eservices_log_t
           SET err = t_msg
         WHERE seq = a_seq;

        COMMIT;

        RETURN json_object(
                   'PACKET_TYPE' VALUE 'MESSAGE',
                   'DATA' VALUE
                       json_object(
                           'MSGNO' VALUE 5,
                           'MSG' VALUE
                               'Oracle Exception","EXCEPTION":"(Seq: '
                               || a_seq
                               || ') '
                               || t_msg));
END;
/
