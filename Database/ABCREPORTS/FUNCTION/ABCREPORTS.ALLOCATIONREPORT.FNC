CREATE OR REPLACE FUNCTION ABCREPORTS.allocationreport(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        allocationreport.fnc
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 02/09/2021 TJL  24000    Initial Report Created
    --- ****************************************************************************

    ln_return_code   NUMBER;
    lv_status_msg    VARCHAR2(4000);
    lb_proc          BOOLEAN := TRUE;
    ld_start_date    DATE;
    ld_end_date      DATE;
    xml_value        XMLTYPE;
    lxml_pi          XMLTYPE;
    ln_              NUMBER;
    blob_            BLOB;
    lv_district      query.o_office.isdistrict%TYPE;
    cur_recs         SYS_REFCURSOR;
    lv_db            VARCHAR2(12);
    lv_link          VARCHAR2(400);
BEGIN
    ld_start_date   := TRUNC(TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY'));
    ld_end_date     := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY') + (1 - 1 / (24 * 60 * 60));
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    abcreports.f_utils.get_revenue(ld_start_date, ld_end_date);

    SELECT XMLELEMENT(
               "ROOT",
               xmlattributes(TO_CHAR(SYSDATE, 'MM/DD/YYYY') AS "REPORT_TAKEN",
                             NVL(p_parms.get_value('REPORT_NAME'), 'unknown') AS "REPORT_NAME",
                                TO_CHAR(ld_start_date, 'MM/DD/YYYY')
                             || ' to '
                             || TO_CHAR(ld_end_date, 'MM/DD/YYYY') AS "REPORT_DATE"),
               XMLELEMENT(
                   "TOTALS",
                   (SELECT DISTINCT XMLFOREST(generalfund,
                                              abcfunds,
                                              ab_surcharge,
                                              dmv_surcharge_amt,
                                              dishonoredcharge,
                                              fingerprint,
                                              rbsfp,
                                              fingerprinttotal,
                                              rbscc,
                                              miscfees,
                                              grandtotal)
                      FROM (WITH
                                a
                                AS
                                    (SELECT COUNT(feeid)
                                                cnt,
                                            SUM(earnedamount)
                                                earnedamount,
                                            SUM(originalfee)
                                                originalfee,
                                            SUM(penalties)
                                                penalties,
                                            SUM(servicechargeamount)
                                                servicechargeamount,
                                            SUM(ab_surcharge)
                                                ab_surcharge,
                                            SUM(dmv_surcharge_amt)
                                                dmv_surcharge_amt,
                                            SUM(bpu_fee)
                                                bpu_fee,
                                            SUM(CASE WHEN feeactivity = 'CHK' THEN earnedamount ELSE 0 END)
                                                chk,
                                            SUM(CASE WHEN feeactivity = 'POIC' THEN earnedamount ELSE 0 END)
                                                poic,
                                            SUM(CASE WHEN feeactivity IN ('SFP', 'FFP') THEN earnedamount ELSE 0 END)
                                                fingerprint,
                                            SUM(CASE
                                                    WHEN a.miscfee = 'Y'
                                                     AND a.feeactivity = 'RBSCC' THEN
                                                        earnedamount
                                                    ELSE
                                                        0
                                                END)
                                                rbscc,
                                            SUM(CASE
                                                    WHEN a.miscfee = 'Y'
                                                     AND a.feeactivity IN ('RBSSFP', 'RBSFFP') THEN
                                                        earnedamount
                                                    ELSE
                                                        0
                                                END)
                                                rbsfp,
                                            SUM(CASE
                                                    WHEN a.miscfee = 'Y'
                                                     AND a.feeactivity NOT IN ('RBSCC', 'RBSSFP', 'RBSFFP') THEN
                                                        earnedamount
                                                    ELSE
                                                        0
                                                END)
                                                miscfees
                                       FROM abcreports.f_transactions_rpt a -- abc.fn_revenue_detail a
                                      WHERE a.earnedamount != 0)
                            SELECT poic
                                       generalfund,
                                   (  earnedamount
                                    - ab_surcharge
                                    - dmv_surcharge_amt
                                    - poic
                                    - fingerprint
                                    - rbsfp
                                    - chk
                                    - rbscc
                                    - miscfees)
                                       abcfunds,
                                   ab_surcharge,
                                   dmv_surcharge_amt,
                                   chk
                                       dishonoredcharge,
                                   fingerprint,
                                   rbsfp,
                                   (fingerprint + rbsfp)
                                       fingerprinttotal,
                                   rbscc,
                                   miscfees,
                                   earnedamount
                                       grandtotal
                              FROM a))),
               XMLELEMENT(
                   "DETAILS",
                   (SELECT DISTINCT XMLAGG(XMLELEMENT("DETAIL",
                                                      XMLFOREST(licensetype,
                                                                description,
                                                                earnedamount amountsub,
                                                                cnt
                                                                   ))
                                           ORDER BY
                                               licensetype,
                                               CASE REGEXP_SUBSTR(description,
                                                                  '[^ ]+',
                                                                  1,
                                                                  1)
                                                   WHEN 'APP' THEN 1
                                                   WHEN 'ANN' THEN 2
                                                   WHEN 'DOR' THEN 3
                                                   WHEN 'REN' THEN 4
                                                   WHEN 'REN50' THEN 5
                                                   WHEN 'REN100' THEN 6
                                                   ELSE 7
                                               END,
                                               description)
                      FROM (WITH
                                f
                                AS
                                    (SELECT t.feelicensetypecode licensetype,
                                            api.pkg_columnquery.VALUE(rd.feeobjid, 'DescriptionForDisplay')
                                                description,
                                            rd.earnedamount,
                                            rd.feeactivity,
                                            rd.ab_surcharge,
                                            rd.bpu_fee,
                                            rd.dmv_surcharge_amt,
                                            rd.feeamount,
                                              rd.feeamount
                                            - ABS(rd.ab_surcharge)
                                            - ABS(rd.dmv_surcharge_amt)
                                            - CASE WHEN rd.earnedamount > 0 THEN rd.earnedamount ELSE 0 END
                                                ttl,
                                            rd.feeobjid,
                                            rd.miscfee
                                       FROM abcreports.f_transactions_rpt rd -- abc.fn_revenue_detail rd
                                            JOIN abcreports.f_transactions t
                                            ON t.feeid = rd.feeid
                                            and t.transactiontypeid = 1
                                            )
                              SELECT f.licensetype,
                                     CASE
                                         WHEN f.miscfee = 'Y' THEN
                                             f.description
                                         ELSE
                                                REGEXP_SUBSTR(f.description,
                                                              '[^ ]+',
                                                              1,
                                                              3)
                                             || ' '
                                             || REGEXP_SUBSTR(f.description,
                                                              '[^ ]+',
                                                              1,
                                                              4)
                                     END
                                         description,
                                     SUM(earnedamount)
                                         earnedamount,
                                     COUNT(description)
                                         cnt
                                FROM f
                            GROUP BY f.miscfee, f.licensetype, description))))
      INTO xml_value
      FROM DUAL;

    IF (xml_value IS NULL) THEN
        xml_value   := xmltype('<ROOT></ROOT>');
    END IF;

    SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/allocationreport.xslt" type="text/xsl"')
      INTO lxml_pi
      FROM DUAL;

    blob_           :=
        rqs_utils.clob2blob(   lxml_pi.getclobval()
                            || xml_value.getclobval());

    RETURN blob_;
EXCEPTION
    WHEN OTHERS THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Allocation Report',
                      p_msg       => SQLERRM,
                      p_additional_data => NULL,
                      p_error_trace => DBMS_UTILITY.format_error_backtrace);

        p_status_ind   := 'E';

        RETURN UTL_RAW.cast_to_raw(   'ERROR: '
                                   || SQLERRM
                                   || CHR(10)
                                   || CHR(13)
                                   || 'TRACE: '
                                   || DBMS_UTILITY.format_error_backtrace);
END allocationreport;
/
