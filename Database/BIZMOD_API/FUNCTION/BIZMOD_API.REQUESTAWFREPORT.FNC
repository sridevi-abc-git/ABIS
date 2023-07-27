CREATE OR REPLACE FUNCTION BIZMOD_API.requestawfreport(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTAWFREPORT.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :    This function is called thru the eservices API to return
    --              previous ABC-261 license information. A JSON packet license number
    --              is passed into this function to retrieve the information
    --              required by LSP. The license lnformation will be returned
    --              in a JSON packet.
    --
    -- History:
    -------------------------------------------------------------------------------
    --  VER:      Date           Ticket     Comment
    --   1.0  07/24/2023 TJL  BIZ-12102      Initial Function Created
    -- ****************************************************************************

        t_json_obj     json_object_t;
        t_data_obj     json_object_t;
        t_elem         json_element_t;


        t_json_info_obj json_object_t := json_object_t();
        t_data_arr     json_array_t;
        t_json_info    json_array_t;

        t_licensenumber VARCHAR2(10);
        t_fromdate     DATE;
        t_todate       DATE;
        t_branchapplies VARCHAR2(1);
        t_feerequired  NUMBER;
        t_previousamount NUMBER;
        t_adjustedamount number;
        t_gallonage     NUMBER;
        t_results      CLOB;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_msg          VARCHAR2(4000 BYTE);
    BEGIN
        -- ****************************************************************************
        --
        -- ****************************************************************************
        t_json_obj :=
            NEW json_object_t(
                    json_object('PACKET_TYPE' VALUE 'AWFREPORTINFO'));
        t_json_obj.put('DATA', NEW json_array_t());
        t_data_arr := t_json_obj.get_array('DATA');

        SELECT licensenumber, fromdate, todate
          INTO t_licensenumber, t_fromdate, t_todate
          FROM JSON_TABLE(
                   a_packet,
                   '$'
                   COLUMNS(
                       packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                       NESTED PATH '$.DATA[*]'
                           COLUMNS(
                                NESTED PATH '$.LICENSENUMBER[*]'
                                   COLUMNS (licensenumber varchar2(10) path '$'),
                               fromdate DATE
                                   PATH '$.FROMDATE'
                                   DEFAULT '2010-07-01T00:00:00' ON EMPTY,
                               todate DATE
                                   PATH '$.TODATE'
                                   DEFAULT '2099-01-01T00:00:00' ON EMPTY)));

        FOR lt
            IN (SELECT o.objectid                                      jobid,
                       api.pkg_columnquery.VALUE(o.objectid,
                                                 'LicenseTypeCode')    licensetypecode
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex(
                                   a_objectdefname => 'j_LicenseType',
                                   a_columnname =>
                                       'dup_LicenseExternalFileNum',
                                   a_value     => t_licensenumber)
                                   AS api.udt_objectlist)) o)
        LOOP
            CONTINUE WHEN lt.licensetypecode NOT IN ('02', '22');

            -- make sure not a branch
            SELECT CASE NVL(cnt, 0) WHEN 0 THEN 'N' ELSE 'Y' END
              INTO t_branchapplies
              FROM (SELECT COUNT(1)     cnt
                      FROM api.relationships r
                     WHERE (r.endpointid =
                            api.pkg_configquery.endpointidforname(
                                'j_LicenseType',
                                'MasterBranchLicenseType')
                         OR r.endpointid =
                            api.pkg_configquery.endpointidforname(
                                'j_LicenseType',
                                'MasterLicenseType'))
                       AND r.fromobjectid = lt.jobid);

            CONTINUE WHEN t_branchapplies = 'Y';

            t_json_info_obj := NEW json_object_t();
            t_json_info_obj.put('INFO', NEW json_array_t());

            t_data_arr.append(
                NEW json_object_t(
                        json_object(
                            'LICENSENUMBER' VALUE t_licensenumber,
                            'LICENSETYPECODE' VALUE lt.licensetypecode)));

            t_elem := t_data_arr.get(0);
            t_data_obj := TREAT(t_elem AS json_object_t);

            t_data_obj.put('INFO', NEW json_array_t());

            t_json_info := t_data_obj.get_array('INFO');

            -- get awf information for license type by date range
            FOR rec
                IN (  SELECT f.*
                        FROM api.fees f
                       WHERE f.description LIKE '%AWF%'
                         AND f.jobid = lt.jobid
                         AND TRUNC(f.transactiondate) BETWEEN t_fromdate
                                                          AND t_todate
                    ORDER BY f.transactiondate)
            LOOP
                -- get awf entered information
                t_gallonage := null;
--                FOR i
--                    IN (
                    WITH
                            b
                            AS
                                (SELECT /*+ materialize */
                                        bpe.fromobjectid,
                                        api.pkg_columnquery.VALUE(
                                            objectid,
                                            'paymentbatchtype')
                                            paymentbatchtype,
                                        api.pkg_columnquery.VALUE(
                                            bpe.toobjectid,
                                            'licensenum')
                                            licensenum,
                                        api.pkg_columnquery.VALUE(
                                            bpe.toobjectid,
                                            'licensetypecode')
                                            licensetypecode,
                                        api.pkg_columnquery.VALUE(
                                            bpe.toobjectid,
                                            'gallonage')
                                            gallonage,
                                        api.pkg_columnquery.VALUE(
                                            bpe.toobjectid,
                                            'TotalPaidAmount')
                                            awfpaidamount
                                   FROM TABLE(
                                            CAST(
                                                api.pkg_simplesearch.castableobjectsbyindex(
                                                    a_objectdefname =>
                                                        'j_paymentbatch',
                                                    a_columnname =>
                                                        'BatchDate',
                                                    a_value     =>
                                                        TO_CHAR(
                                                            rec.transactiondate,
                                                            'yyyy-mm-dd'))
                                                    AS api.udt_objectlist)) o
                                        JOIN api.relationships bpe
                                            ON (bpe.endpointid =
                                                api.pkg_configquery.endpointidforname(
                                                    a_fromobjectdefname =>
                                                        'j_paymentbatch',
                                                    a_name      =>
                                                        'BatchPaymentEntry')
                                            AND o.objectid = bpe.fromobjectid)
                                  WHERE api.pkg_columnquery.VALUE(
                                            bpe.fromobjectid,
                                            'PAYMENTBATCHTYPE') =
                                        'ADDITIONAL WINE FEES (AWF)')
                        SELECT max(b.gallonage)
                          INTO t_gallonage
                          FROM b
                         WHERE b.licensenum = t_licensenumber;
--                LOOP
                    --continue;
                    --dbms_output.put_line('fee: ' || api.pkg_columnquery.value(rec.feeobjid, 'FeeCode'));

--dbms_output.put_line('Date: ' || to_char(rec.transactiondate, 'mon dd, yyyy') || chr(9)
--                 || 'From: ' || i.fromobjectid || chr(9)
--                 || 'Gallonage: ' || i.gallonage || chr(9)
--                 || 'awfpaid: ' || i.awfpaidamount);

-- no longer valid below procedure
                    bizmod_api.utl_licenseinfo.get_awfreninfo(
                        a_fiscalend =>
                            TO_DATE(
                                '30-06-'
                                || EXTRACT(
                                       YEAR FROM ADD_MONTHS(
                                                     rec.transactiondate,
                                                     6)),
                                'dd-mm-yyyy'),
                        a_jobid     => lt.jobid,
                        a_gallonage => t_gallonage,
                        a_feerequired => t_feerequired,
                        a_adjustedamount => t_adjustedamount,
                        a_paidamount => t_previousamount);

                    t_json_info.append(
                        NEW json_object_t(
                                json_object(
                                    'SUBMITTEDDATE' VALUE rec.transactiondate,
                                    'GALLONAGE' VALUE NVL(i.gallonage, 'NA'),
                                    'FEEREQUIRED' VALUE t_feerequired,
                                    'PREVIOUSPAYMENT' VALUE t_previousamount,
                                    'AWFPAID' VALUE i.awfpaidamount)));
--                END LOOP;
            END LOOP;
        END LOOP;

        utl_licenseinfo.clean(a_json => t_json_obj);
        RETURN t_json_obj.TO_CLOB;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;
            t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

            SELECT json_object(
                       'PACKET_TYPE' VALUE 'MESSAGE',
                       'DATA' VALUE
                           json_object(
                               'MSGNO' VALUE 5,
                               'MSG' VALUE 'Oracle Exception',
                               'EXCEPTION' VALUE
                                   REGEXP_REPLACE(
                                       t_sqlerrm || ' ** ' || t_trace,
                                       '[^[:print:]]',
                                       ' ')))
              INTO t_results
              FROM DUAL;

            RETURN t_results;
    END;
/
