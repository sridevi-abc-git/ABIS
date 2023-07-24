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
    t_json_data    json_array_t;
    t_json_info    json_array_t;

    t_licensenumber VARCHAR2(10);
    t_fromdate     DATE;
    t_todate       DATE;
    t_branchapplies VARCHAR2(1);
BEGIN
    -- ****************************************************************************
    --
    -- ****************************************************************************
    t_json_obj :=
        NEW json_object_t(
                json_object('PACKET_TYPE' VALUE 'LICENSELISTINFO',
                            'DATA' VALUE NEW json_array_t()));
    --        t_json_obj.put('DATA', new json_array_t());
    t_json_data := t_json_obj.get_array('DATA');

    SELECT licensenumber, fromdate, todate
      INTO t_licensenumber, t_fromdate, t_todate
      FROM JSON_TABLE(
               a_packet,
               '$'
               COLUMNS(
                   packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                   NESTED PATH '$.DATA[*]'
                       COLUMNS(
                           licensenumber VARCHAR2(1000)
                               PATH '$.LICENSENUMBER',
                           fromdate DATE
                               PATH '$.FROMDATE'
                               DEFAULT '01-jan-2010' ON EMPTY,
                           todate DATE
                               PATH '$.TODATE'
                               DEFAULT '31-dec-2099' ON EMPTY)));

    FOR lt
        IN (SELECT o.objectid                                                  jobid,
                   api.pkg_columnquery.VALUE(o.objectid, 'LicenseTypeCode')    licensetypecode
              FROM TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindex(
                               a_objectdefname => 'j_LicenseType',
                               a_columnname => 'dup_LicenseExternalFileNum',
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
                   AND r.fromobjectid = a_licensetypeobjectid);

        CONTINUE WHEN t_branchapplies = 'Y';

        t_json_data.append(
            NEW json_object_t(
                    json_object('LICENSENUMBER' VALUE lt.licensenumber,
                                'LICENSETYPECODE' VALUE lt.licensetypecode,
                                'INFO' VALUE NEW json_array_t())));
        t_json_info := t_json_data.get_array('INFO');

        -- get awf information for license type by date range
        FOR rec
            IN (  SELECT f.*
                    FROM api.fees f
                   WHERE f.description LIKE '%AWF%'
                     AND f.jobid = licenseobjecttypeid
                     AND TRUNC(f.transactiondate) BETWEEN lt.fromdate
                                                      AND lt.todate
                ORDER BY f.transactiondate)
        LOOP
            -- get awf entered information
            FOR i
                IN (WITH
                        b
                        AS
                            (SELECT /*+ materialize */
                                    bpe.fromobjectid,
                                    api.pkg_columnquery.VALUE(
                                        objectid,
                                        'paymentbatchtype')
                                        paymentbatchtype,
                                    api.pkg_columnquery.VALUE(bpe.toobjectid,
                                                              'licensenum')
                                        licensenum,
                                    api.pkg_columnquery.VALUE(
                                        bpe.toobjectid,
                                        'licensetypecode')
                                        licensetypecode,
                                    api.pkg_columnquery.VALUE(bpe.toobjectid,
                                                              'gallonage')
                                        gallonage,
                                    api.pkg_columnquery.VALUE(
                                        bpe.toobjectid,
                                        'TotalPaidAmount')
                                        totalpaidamount
                               FROM TABLE(
                                        CAST(
                                            api.pkg_simplesearch.castableobjectsbyindex(
                                                a_objectdefname =>
                                                    'j_paymentbatch',
                                                a_columnname => 'BatchDate',
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
                    SELECT *
                      FROM b
                     WHERE b.licensenum = t_licensenumber)
            LOOP

        t_json_innfo.append(
            NEW json_object_t(
                    json_object('SUBMITTEDDATE' VALUE rec.transactiondate,
                                'GALLONAGE' VALUE NVL(gallonage, 'NA'),
                                'FEEREQUIRED' VALUE 'NA',
                                'PREVIOUSPAYMENT' VALUE 0 ,
                                'AMOUNTDUE' VALUE totalpaidamount 
                                )));
            
            END LOOP;
        END LOOP;
    END LOOP;
END;
/
