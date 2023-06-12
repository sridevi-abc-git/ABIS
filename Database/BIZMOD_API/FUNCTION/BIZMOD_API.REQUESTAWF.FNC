CREATE OR REPLACE FUNCTION requestawf(a_packet IN CLOB, a_seq IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        REQUESTAWF.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :    This function is called thru the eservices API to return
    --              ABC-261 license information. A JSON packet license number
    --              is passed into this function to retrieve the information
    --              required by LSP. The license lnformation will be returned
    --              in a JSON packet.
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date           Ticket     Comment
    --  06/08/2022 TJL  BIZ-      Initial Function Created
    --  02/16/2023 TJL            Converted to using JSON objects.
    -- ****************************************************************************

    -- ****************************************************************************
    --
    -- ****************************************************************************
    t_objectid     api.pkg_definition.udt_id;
    t_licensenumber VARCHAR2(10);
    t_branchapplies VARCHAR2(1);
    t_renfeeid     NUMBER;
    t_feeobjid     NUMBER;
    t_awfdate      DATE;
    t_renfeeactivity VARCHAR2(20);
    t_feeactivity  VARCHAR2(20);
    t_awf          VARCHAR2(4000);
    t_feeid        NUMBER;
    t_description  VARCHAR2(200);
    t_paidamount   NUMBER;
    t_cnt          NUMBER := 0;
    t_info         CLOB;
    t_msgno        NUMBER;
    t_issuedate    DATE;
    t_expiration   DATE;
    l_obj          json_object_t;
    l_data         json_object_t;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000);
-- ****************************************************************************
-- ****************************************************************************
--  Main Function Body
-- ****************************************************************************
-- ****************************************************************************
BEGIN
    -- get license number from request packet
    SELECT json_value(a_packet, '$.*.LICENSENUMBER')
      INTO t_licensenumber
      FROM DUAL;

    -- Get license type job id from license number for only license types 02 and 22
    WITH
        licensetypes
        AS
            (SELECT o.objectid,
                    api.pkg_columnquery.VALUE(o.objectid, 'LicenseTypeCode')    licensetypecode
               FROM TABLE(
                        CAST(
                            api.pkg_simplesearch.castableobjectsbyindex(
                                a_objectdefname => 'j_LicenseType',
                                a_columnname => 'dup_LicenseExternalFileNum',
                                a_value     => t_licensenumber)
                                AS api.udt_objectlist)) o)
    SELECT objectid
      INTO t_objectid
      FROM licensetypes lt
     WHERE lt.licensetypecode IN ('02', '22');

    t_expiration :=
        api.pkg_columnquery.datevalue(t_objectid, 'ExpirationDate');
    t_issuedate := api.pkg_columnquery.datevalue(t_objectid, 'IssueDate');

    -- check if branch license
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
               AND r.fromobjectid = t_objectid);

    -- make sure that this license has been renewed in the pass not issued this year
    IF (t_issuedate >= ADD_MONTHS(t_expiration, -12))
    THEN
        t_msgno := 10;
    ELSE
        -- get latest renewal fee
        SELECT f.feeid,
               f.transactiondate,
               (SELECT REGEXP_SUBSTR(
                           api.pkg_columnquery.VALUE(
                               reo.objectid,
                               'FeeScheduleDescription'),
                           '[^ ]+',
                           1,
                           3)
                  FROM api.registeredexternalobjects reo
                 WHERE reo.objectdefid =
                       api.pkg_configquery.objectdefidforname('o_fee')
                   AND reo.linkvalue = TO_CHAR(f.feeid) -- feeid
                                                       )    description,
               f.paidamount
          INTO t_renfeeid,
               t_awfdate,
               t_renfeeactivity,
               t_paidamount
          FROM api.fees f
         WHERE f.jobid = t_objectid
           AND f.description LIKE '02%REN%'
           AND f.transactiondate =
               (SELECT MAX(f2.transactiondate)
                  FROM api.fees f2
                 WHERE f.jobid = f2.jobid -- t_objectid
                   AND f2.description LIKE '02%REN%'
                   AND f2.transactiondate BETWEEN ADD_MONTHS(t_expiration,
                                                            -24)
                                             AND ADD_MONTHS(t_expiration, -12));

        CASE
            WHEN t_branchapplies = 'Y'
            THEN
                t_msgno := 8;
            --            WHEN (t_paidamount < 0)
            --            THEN
            ELSE
                -- license has been renewed for this year
                -- check if AWF fee was paid for this renewal
                SELECT SUM(cnt)
                  INTO t_cnt
                  FROM (SELECT COUNT(1)     cnt
                          FROM api.fees f
                         WHERE f.jobid = t_objectid
                           AND trunc(f.transactiondate) >= t_awfdate
                           AND f.description LIKE '%AWF%'
                        UNION
                        SELECT COUNT(1)     cnt
                          FROM bizmod_api.e_payments_t p
                         WHERE (p.licensenumber = t_licensenumber
                            AND p.licensetypecode = '02'
                            AND p.description LIKE '%AWF%'
                            AND trunc(p.createddate) >= t_awfdate));

                SELECT reo.objectid
                  INTO t_feeobjid
                  FROM api.registeredexternalobjects reo
                 WHERE reo.objectdefid =
                       api.pkg_configquery.objectdefidforname('o_fee')
                   AND reo.linkvalue = TO_CHAR(t_renfeeid);

                IF (t_cnt = 0)
                THEN
                    MERGE INTO awf_t a
                         USING (SELECT t_renfeeid renfeeid FROM DUAL) a2
                            ON (a.renfeeid = a2.renfeeid)
                    WHEN NOT MATCHED
                    THEN
                        INSERT     (renfeeid,
                                    renfeeobjid,
                                    licensenumber,
                                    licensetypejobid,
                                    licensetypecode,
                                    expirationdate,
                                    awfdate,
                                    renactivity,
                                    currgallonage,
                                    curraddionalgallonage,
                                    renewalamountpaid)
                            VALUES (
                                t_renfeeid,
                                t_feeobjid,
                                t_licensenumber,
                                t_objectid,
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'LicenseTypeCode'),
                                t_expiration,
                                t_awfdate,
                                t_renfeeactivity,
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'GallonageRange'),
                                api.pkg_columnquery.numericvalue(
                                    t_objectid,
                                    'AdditionalMillionGallons'),
                                t_paidamount);

                    COMMIT;
                ELSE
                    t_msgno := 9;
                END IF;
        --            ELSE
        --                t_msgno := 7;
        END CASE;
    END IF;

    l_obj :=
        NEW json_object_t(
                json_object(
                    'PACKET_TYPE' VALUE 'LICENSEAWFINFO',
                    'DATA' VALUE
                        json_object(
                            'LICENSEOBJECTID' VALUE t_objectid,
                            'LICENSENUMBER' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'licensenumber'),
                            'PRIMARYLICENSEE' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'PrimaryLicensee'), -- PRIMARY OWNER
                            'BUSINESSNAME' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'PrimaryDBA'), -- DBA
                            'PREMISEADDRESS' VALUE
                                TRIM(
                                    api.pkg_columnquery.VALUE(
                                        t_objectid,
                                        'PremAddress1stOf2Lines')), -- business address
                            'PREMISECITYSTYZIP' VALUE
                                api.pkg_columnquery.VALUE(
                                    t_objectid,
                                    'PremAddress2ndOf2Lines'))));

    IF (t_msgno IS NOT NULL)
    THEN
        l_data := l_obj.get_object('DATA');
        l_data.put('MSGNO', t_msgno);
        l_data.put(
            'MSG',
            CASE t_msgno
                WHEN 7 THEN 'License has not been renewed for this year.'
                WHEN 8 THEN 'License is a Branch License.'
                WHEN 9 THEN 'AFW Fee already paid for this renewal year.'
                WHEN 10 THEN 'License was issued this licensing period.'
                ELSE 'Unknown error'
            END);
    ELSE
        SELECT json_object(
                   'FEEID' VALUE t.renfeeid,
                   'LICENSETYPECODE' VALUE t.licensetypecode,
                   'DESCRIPTION' VALUE t.description,
                   'FEEACTIVITY' VALUE t.renactivity,
                   'AWFDATE' VALUE t.awfdate,
                   'EXPIRATIONDATE' VALUE t.expirationdate,
                   'RENEWALAMOUNT' VALUE t.renewalamountpaid,
                   'CURRENTGALLONAGE' VALUE t.currgallonage,
                   'ADDITIONALGALLONAGE' VALUE t.curraddionalgallonage,
                   'CREATEDDATE' VALUE t.createddate,
                   'GALLONAGE' VALUE t.gallonage261,
                   'AWFAMOUNTOWED' VALUE t.awffeeamount,
                   'AWFPAID' VALUE NULL
                   ABSENT ON NULL)
          INTO t_awf
          FROM awf_t  t
               LEFT OUTER JOIN e_payments_t p ON p.feeobjid = t.renfeeobjid
         WHERE t.renfeeid = t_renfeeid;

        l_obj.put('INFO', TREAT(json_object_t.parse(t_awf) AS json_object_t));
    END IF;

    RETURN l_obj.TO_CLOB;
EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);
        DBMS_OUTPUT.put_line(t_msg);

        RETURN json_object(
                   'PACKET_TYPE' VALUE 'MESSAGE',
                   'DATA' VALUE
                       json_object(
                           'MSGNO' VALUE 1,
                           'MSG' VALUE
                               'License Number '
                               || t_licensenumber
                               || ' Not Found'));
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