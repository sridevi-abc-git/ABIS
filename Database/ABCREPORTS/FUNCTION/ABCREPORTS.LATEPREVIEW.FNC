CREATE OR REPLACE FUNCTION ABCREPORTS.latepreview(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        latepreview.fnc
    -- Author:      Timothy J. Lord
    --
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 09/01/2020 TJL 21764 Function created
    -- 04/08/2021 TJL 24552 Added office id, payment id, and payment/transmittal batch id
    -- ****************************************************************************
    -- ************************************************************************
    --  Main process
    -- ************************************************************************
    office_id        t_officeobject;
    lv_status_msg    VARCHAR2(4000);
    lblob_csv        BLOB;
    ld_start         DATE;
    ld_end           DATE;
    lv_csv_row       VARCHAR2(8096);
    lv_report_name   VARCHAR(150) := p_parms.get_value('REPORT_NAME');
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start   := LAST_DAY(TO_DATE(p_parms.get_value('REPORT_DATE'), 'MM/DD/YYYY'));
    p_parms.upd_value('EXPIRATION_DATE', TO_CHAR(ld_start, 'MM/DD/YYYY'));

    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec
        IN (  SELECT    '"'
                     || t.feelicensetypecode
                     || '","'
                     || api.pkg_columnquery.VALUE(t.jobid, 'LicenseNumber')
                     || '","'
                     || api.pkg_columnquery.VALUE(t.jobid, 'PrimaryLicensee')
                     || '","'
                     || api.pkg_columnquery.VALUE(t.jobid, 'PremAddress2Lines')
                     || '","'
                     || api.pkg_columnquery.VALUE(t.jobid, 'BaseFileOfficeName')
                     || '","'
                     || TO_CHAR(api.pkg_columnquery.datevalue(t.jobid, 'dup_ExpirationDate'), 'MM/DD/YYYY')
                     || '","'
                     || t.status
                     || '","'
                     || api.pkg_columnquery.VALUE(t.licensefeeschedid, 'Description')
                     || '",'
                     || (  api.pkg_columnquery.numericvalue(t.feeobjid, 'Amount')
                         + api.pkg_columnquery.numericvalue(t.feeobjid, 'AdjustedAmount'))
                     || ','
                     || t.paidamount
                     || ',"'
                     || CASE
                            WHEN t.paidamount < 0 THEN
                                TO_CHAR((SELECT MAX(ft.transactiondate)
                                           FROM api.feetransactions ft
                                          WHERE ft.feeid = t.feeid),
                                        'mm/dd/yyyy')
                            ELSE
                                ' '
                        END
                     || '","'
                     || t.paymentid
                     || '","'
                     || t.batchid
                     || '"'
                         info
                FROM (SELECT lt.*,
                             api.pkg_columnquery.numericvalue(lt.feeobjid, 'PaidAmount')
                                 paidamount,
                             api.pkg_columnquery.numericvalue(lt.feeobjid, 'LicenseFeeSchedId')
                                 licensefeeschedid,
                             api.pkg_columnquery.VALUE(
                                 api.pkg_columnquery.numericvalue(lt.feeobjid, 'LicenseFeeSchedId'),
                                 'Description')
                                 des,
                             REGEXP_SUBSTR(
                                 api.pkg_columnquery.VALUE(
                                     api.pkg_columnquery.numericvalue(lt.feeobjid, 'LicenseFeeSchedId'),
                                     'Description'),
                                 '[^ ]+',
                                 1,
                                 1)
                                 feeactivity,
                             (NVL(
                                  (SELECT api.pkg_columnquery.VALUE(r.relationshipid, 'Status')
                                     FROM api.relationships r
                                    WHERE r.endpointid =
                                          api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatSecondary')
                                      AND r.fromobjectid = jobid
                                      AND api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode') =
                                          feelicensetypecode
                                      AND ROWNUM = 1),
                                  api.pkg_columnquery.VALUE(jobid, 'StatusName')))
                                 status
                        FROM (WITH
                                  obj
                                  AS
                                      (  SELECT  /*+ materialize */
                                                o.jobid,
                                                f.feeid,
                                                api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', f.feeid) feeobjid,  --reo.objectid,
                                                api.pkg_columnquery.VALUE(reo.objectid, 'PayeeReference') paymentid,
                                                api.pkg_columnquery.VALUE(reo.objectid, 'BatchId')        batchid
                                           FROM (SELECT o.objectid jobid
                                                   FROM TABLE(
                                                            CAST(
                                                                api.pkg_simplesearch.castableobjectsbyindex(
                                                                    'j_LicenseType',
                                                                    'dup_ExpirationDate',
                                                                    TO_CHAR(ld_start, 'YYYY-MM-DD')) AS api.udt_objectlist))
                                                        o
                                                 UNION
                                                 SELECT o.objectid
                                                   FROM TABLE(
                                                            CAST(
                                                                api.pkg_simplesearch.castableobjectsbyindex(
                                                                    'j_LicenseType',
                                                                    'dup_ExpirationDate',
                                                                    TO_CHAR(ADD_MONTHS(ld_start, 12), 'YYYY-MM-DD')) AS api.udt_objectlist))
                                                        o) o
                                                JOIN api.fees f
                                                ON f.jobid = o.jobid
                                                JOIN finance.transactions_t t
                                                ON (t.feeid = f.feeid
                                                 OR t.transactionid = f.feeid)
                                                LEFT OUTER JOIN api.registeredexternalobjects reo2
                                                ON (reo2.objectdefid =
                                                    api.pkg_configquery.objectdefidforname('o_PaymentTransactions')
                                                AND reo2.linkvalue = TO_CHAR(t.transactionid))
                                                LEFT OUTER JOIN api.registeredexternalobjects reo
                                                ON (reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Payment')
                                                AND reo.linkvalue =
                                                    TO_CHAR(api.pkg_columnquery.numericvalue(reo2.objectid, 'Paymentid')))
                                          WHERE t.transactiondate BETWEEN ADD_MONTHS(ld_start, -3) AND ADD_MONTHS(ld_start, 9)
                                       ORDER BY f.feeid)
                                SELECT o.jobid,
                                       api.pkg_columnquery.VALUE(o.jobid, 'LicenseTypeCode')
                                           licensetypecode,
                                       SUBSTR(api.pkg_columnquery.VALUE(o.feeobjid, 'Description'), 1, 2)
                                           feelicensetypecode,
                                       o.feeobjid,
                                       o.feeid,
                                       api.pkg_columnquery.datevalue(o.feeobjid, 'transactiondate')
                                           transactiondate,
                                       api.pkg_columnquery.numericvalue(o.feeobjid, 'amount')
                                           amount,
                                       api.pkg_columnquery.VALUE(o.feeobjid, 'Description')
                                           description,
                                       MAX(
                                           api.pkg_columnquery.datevalue(o.feeobjid, 'transactiondate'))
                                       OVER(
                                           PARTITION BY o.jobid,
                                                        SUBSTR(api.pkg_columnquery.VALUE(o.feeobjid, 'Description'),
                                                               1,
                                                               2))
                                           max_transactiondate,
                                       --                                       LISTAGG(paymentid, ', ') WITHIN GROUP (ORDER BY feeid)
                                       (SELECT LISTAGG(paymentid, ', ') WITHIN GROUP (ORDER BY feeid)
                                          FROM (SELECT DISTINCT paymentid
                                                  FROM obj
                                                 WHERE o.feeid = obj.feeid))
                                           paymentid,
                                       (SELECT LISTAGG(batchid, ', ') WITHIN GROUP (ORDER BY feeid)
                                          FROM (SELECT DISTINCT batchid
                                                  FROM obj
                                                 WHERE o.feeid = obj.feeid))
                                           batchid
                                  FROM obj o
                              GROUP BY jobid, feeid, feeobjid) lt) t
               --
               --
               --        (WITH
               --                trans
               --                AS
               --                    (SELECT lt.*,
               --                            api.pkg_columnquery.numericvalue(lt.feeobjid, 'PaidAmount')
               --                                paidamount,
               --                            api.pkg_columnquery.numericvalue(lt.feeobjid, 'LicenseFeeSchedId')
               --                                licensefeeschedid,
               --                            api.pkg_columnquery.VALUE(
               --                                api.pkg_columnquery.numericvalue(lt.feeobjid, 'LicenseFeeSchedId'),
               --                                'Description')
               --                                des,
               --                            REGEXP_SUBSTR(
               --                                api.pkg_columnquery.VALUE(
               --                                    api.pkg_columnquery.numericvalue(lt.feeobjid, 'LicenseFeeSchedId'),
               --                                    'Description'),
               --                                '[^ ]+',
               --                                1,
               --                                1)
               --                                feeactivity,
               --                            (NVL(
               --                                 (SELECT api.pkg_columnquery.VALUE(r.relationshipid, 'Status')
               --                                    FROM api.relationships r
               --                                   WHERE r.endpointid =
               --                                         api.pkg_configquery.endpointidforname('j_LicenseType',
               --                                                                               'LicTypeCatSecondary')
               --                                     AND r.fromobjectid = jobid
               --                                     AND api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode') =
               --                                         feelicensetypecode
               --                                     AND ROWNUM = 1),
               --                                 api.pkg_columnquery.VALUE(jobid, 'StatusName')))
               --                                status
               --                       FROM (SELECT f.jobid,
               --                                    api.pkg_columnquery.VALUE(f.jobid, 'LicenseTypeCode')
               --                                        licensetypecode,
               --                                    SUBSTR(t.description, 1, 2)
               --                                        feelicensetypecode,
               --                                    api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', t.transactionid)
               --                                        feeobjid,
               --                                    t.transactionid
               --                                        feeid,
               --                                    t.transactiondate,
               --                                    t.amount,
               --                                    t.description,
               --                                    MAX(t.transactiondate) OVER (PARTITION BY f.jobid, SUBSTR(f.description, 1, 2))
               --                                        max_transactiondate
               --                               FROM (SELECT o.objectid jobid
               --                                       FROM TABLE(
               --                                                CAST(
               --                                                    api.pkg_simplesearch.castableobjectsbyindex(
               --                                                        'j_LicenseType',
               --                                                        'dup_ExpirationDate',
               --                                                        TO_CHAR(ld_start, 'YYYY-MM-DD')) AS api.udt_objectlist)) o
               --                                     UNION
               --                                     SELECT o.objectid
               --                                       FROM TABLE(
               --                                                CAST(
               --                                                    api.pkg_simplesearch.castableobjectsbyindex(
               --                                                        'j_LicenseType',
               --                                                        'dup_ExpirationDate',
               --                                                        TO_CHAR(ADD_MONTHS(ld_start, 12), 'YYYY-MM-DD')) AS api.udt_objectlist))
               --                                            o) o
               --                                    JOIN api.fees f
               --                                    ON f.jobid = o.jobid
               --                                    JOIN finance.transactions_t t
               --                                    ON t.transactionid = f.feeid
               --                              WHERE t.transactiondate BETWEEN ADD_MONTHS(ld_start, -3) AND ld_start) lt
               --                      WHERE transactiondate = max_transactiondate)
               --              SELECT    '"'
               --                     || t.feelicensetypecode
               --                     || '","'
               --                     || api.pkg_columnquery.VALUE(t.jobid, 'LicenseNumber')
               --                     || '","'
               --                     || api.pkg_columnquery.VALUE(t.jobid, 'PrimaryLicensee')
               --                     || '","'
               --                     || api.pkg_columnquery.VALUE(t.jobid, 'PremAddress2Lines')
               --                     || '","'
               --                     || TO_CHAR(api.pkg_columnquery.datevalue(t.jobid, 'dup_ExpirationDate'), 'MM/DD/YYYY')
               --                     || '","'
               --                     || t.status
               --                     || '","'
               --                     || api.pkg_columnquery.VALUE(t.licensefeeschedid, 'Description')
               --                     || '",'
               --                     || (  api.pkg_columnquery.numericvalue(t.feeobjid, 'Amount')
               --                         + api.pkg_columnquery.numericvalue(t.feeobjid, 'AdjustedAmount'))
               --                     || ','
               --                     || t.paidamount
               --                     || ',"'
               --                     || CASE
               --                            WHEN t.paidamount < 0 THEN
               --                                TO_CHAR((SELECT MAX(ft.transactiondate)
               --                                           FROM api.feetransactions ft
               --                                          WHERE ft.feeid = t.feeid),
               --                                        'mm/dd/yyyy')
               --                            ELSE
               --                                ' '
               --                        END
               --                     || '"'
               --                         info
               --                FROM trans t
               WHERE t.feeactivity IN ('REN', 'REN50', 'REN100')
            ORDER BY LPAD(api.pkg_columnquery.VALUE(t.jobid, 'LicenseNumber'), 6, 0), t.licensetypecode)
    LOOP
        lv_csv_row   :=
               REGEXP_REPLACE(rec.info, '[[:cntrl:]]', '')
            || CHR(13)
            || CHR(10);

        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
    END LOOP;

    COMMIT;
    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'latepreview',
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
END latepreview;
/
