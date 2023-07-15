CREATE OR REPLACE FUNCTION BIZMOD_API.requestawf(a_packet       IN CLOB,
                                                 a_seq          IN NUMBER)
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
    --  06/28/2023 TJL            Fixed bug in generating return packet
    --  07/06/2023 TJL  BIZ-11891   Change which renewal fee being returned
    -- ****************************************************************************

    -- ****************************************************************************
    --
    -- ****************************************************************************
    t_objectid     api.pkg_definition.udt_id;
    t_licensenumber VARCHAR(10);
    t_issuedate    DATE;
    t_expiration   DATE;
    t_start_date   DATE;
    t_end_date     DATE;
    t_application  NUMBER;
    t_applicationtype VARCHAR2(20);
    t_transferfromobjectid NUMBER;
    t_msgno        NUMBER;
    t_renfeeid     NUMBER;
    t_feeobjid     NUMBER;
    t_awfdate      DATE;
    t_renfeeactivity VARCHAR2(20);
    t_feeactivity  VARCHAR2(20);
    t_awf          VARCHAR2(4000);
    t_feeid        NUMBER;
    t_description  VARCHAR2(200);
    t_paidamount   NUMBER;
    l_data         json_object_t;
    l_obj          json_object_t;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    -- get license number from request packet
    SELECT json_value(a_packet, '$.*.LICENSENUMBER')
      INTO t_licensenumber
      FROM DUAL;

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

    t_msgno := bizmod_api.utl_licenseinfo.awfrequired(t_objectid);

    IF (t_msgno IS NULL)
    THEN
        t_expiration :=
            api.pkg_columnquery.datevalue(t_objectid, 'ExpirationDate');
        t_issuedate := api.pkg_columnquery.datevalue(t_objectid, 'IssueDate');

        t_start_date := ADD_MONTHS(t_expiration + 1, -24);
        t_end_date := ADD_MONTHS(t_expiration, -12);

        -- get application for this license
        SELECT a.toobjectid
          INTO t_application
          FROM api.relationships  l
               JOIN api.relationships a
                   ON (a.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_License',
                           'ApplicationLicense')
                   AND a.fromobjectid = l.toobjectid)
         WHERE l.endpointid =
               api.pkg_configquery.endpointidforname('j_LicenseType',
                                                     'License')
           AND l.fromobjectid = t_objectid;

        t_applicationtype :=
            api.pkg_columnquery.VALUE(t_application, 'ApplicationType');

        IF (t_applicationtype = 'Transfer')
        THEN
            -- find license transfer from
            SELECT lt.toobjectid
              INTO t_transferfromobjectid
              FROM api.relationships lt
             WHERE (lt.endpointid =
                    api.pkg_configquery.endpointidforname('j_License',
                                                          'LicenseType')
                AND lt.fromobjectid =
                    api.pkg_columnquery.numericvalue(
                        t_application,
                        'TransferFromLicenseObjectId')
                AND api.pkg_columnquery.VALUE(lt.toobjectid,
                                              'LicenseTypeCode') =
                    '02');
        END IF;


        CASE
            -- get renewal fee information for licenses over a couple of years old
            WHEN TRUNC(t_issuedate) <= ADD_MONTHS(t_expiration + 1, -24)
            THEN
                -- get renewal fee
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
                               api.pkg_configquery.objectdefidforname(
                                   'o_fee')
                           AND reo.linkvalue = TO_CHAR(f.feeid) -- feeid
                                                               )
                           description,
                       f.paidamount
                  INTO t_renfeeid,
                       t_awfdate,
                       t_renfeeactivity,
                       t_paidamount
                  FROM api.fees f
                 WHERE f.jobid = t_objectid
                   AND (f.description LIKE '02 - REN%'
                     OR f.description LIKE '22 - REN%')
                   AND f.transactiondate BETWEEN t_start_date AND t_end_date;
            -- for licenses issued this year get renewal fees from previous license
            WHEN TRUNC(t_issuedate) BETWEEN ADD_MONTHS(t_expiration + 1, -12)
                                        AND t_expiration
            THEN
                -- get renewal fee
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
                               api.pkg_configquery.objectdefidforname(
                                   'o_fee')
                           AND reo.linkvalue = TO_CHAR(f.feeid) -- feeid
                                                               )
                           description,
                       f.paidamount
                  INTO t_renfeeid,
                       t_awfdate,
                       t_renfeeactivity,
                       t_paidamount
                  FROM api.fees f
                 WHERE f.jobid = t_transferfromobjectid
                   AND (f.description LIKE '02 - REN%'
                     OR f.description LIKE '22 - REN%')
                   AND f.transactiondate BETWEEN t_start_date AND t_end_date;
            ELSE
                -- get renewal fee or ANN fee for licenses issued last fiscal year
                IF ((t_applicationtype = 'Original')
                 OR (t_applicationtype = 'Transfer'
                 AND api.pkg_columnquery.VALUE(t_application,
                                               'PersonToPerson') =
                     'Y')
                 OR (t_applicationtype = 'Change'
                 AND api.pkg_columnquery.VALUE(t_application,
                                               'AddPrimaryLicenseType') =
                     'Y'))
                THEN
                    -- get ANN Fees
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
                                   api.pkg_configquery.objectdefidforname(
                                       'o_fee')
                               AND reo.linkvalue = TO_CHAR(f.feeid) -- feeid
                                                                   )
                               description,
                           f.paidamount
                      INTO t_renfeeid,
                           t_awfdate,
                           t_renfeeactivity,
                           t_paidamount
                      FROM api.fees f
                     WHERE f.jobid = t_application
                       AND SUBSTR(f.description, 1, 2) IN ('02', '22')
                       AND (f.description LIKE '%ANN%');
                ELSE
                    -- get ren fees from tranfered license
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
                                   api.pkg_configquery.objectdefidforname(
                                       'o_fee')
                               AND reo.linkvalue = TO_CHAR(f.feeid) -- feeid
                                                                   )
                               description,
                           f.paidamount
                      INTO t_renfeeid,
                           t_awfdate,
                           t_renfeeactivity,
                           t_paidamount
                      FROM api.fees f
                     WHERE f.jobid = t_transferfromobjectid
                       AND (f.description LIKE '02 - REN%'
                         OR f.description LIKE '22 - REN%')
                       AND f.transactiondate BETWEEN t_start_date
                                                 AND t_end_date;
                END IF;
        END CASE;

        SELECT reo.objectid
          INTO t_feeobjid
          FROM api.registeredexternalobjects reo
         WHERE reo.objectdefid =
               api.pkg_configquery.objectdefidforname('o_fee')
           AND reo.linkvalue = TO_CHAR(t_renfeeid);

        MERGE INTO bizmod_api.awf_t a
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
                    api.pkg_columnquery.VALUE(t_objectid, 'LicenseTypeCode'),
                    t_expiration,
                    t_awfdate,
                    t_renfeeactivity,
                    api.pkg_columnquery.VALUE(t_objectid, 'GallonageRange'),
                    api.pkg_columnquery.numericvalue(
                        t_objectid,
                        'AdditionalMillionGallons'),
                    t_paidamount);

        COMMIT;
    END IF;

    l_obj :=
        NEW json_object_t(
                json_object(
                    'PACKET_TYPE' VALUE 'LICENSEAWFINFO',
                    'DATA' VALUE
                        json_object(
                            --                            'LICENSEOBJECTID' VALUE t_objectid,
                            'LICENSENUMBER' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'licensenumber'),
                            'LICENSEENAME' VALUE
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

    l_data := l_obj.get_object('DATA');

    IF (t_msgno IS NOT NULL)
    THEN
        l_data.put('MSGNO', t_msgno);
        l_data.put(
            'MSG',
            CASE t_msgno
                WHEN 7 THEN 'License has not been renewed for this year.'
                WHEN 8 THEN 'License is a Branch License.'
                WHEN 9 THEN 'AFW Fee already paid for this renewal year.'
                WHEN 10 THEN 'License was issued this licensing period.'
                WHEN 0 THEN 'Application Annual Fee Not Found'
                ELSE 'Unknown error'
            END);
    ELSE
        SELECT json_object(
                   'FEEID' VALUE t.renfeeid,
                   'LICENSETYPECODE' VALUE t.licensetypecode,
                   'DESCRIPTION' VALUE t.description,
                   'FEEACTIVITY' VALUE t.renactivity,
                   'EXPIRATIONDATE' VALUE t.expirationdate,
                   'AWFDATE' VALUE t.awfdate,
                   'RENEWALAMOUNT' VALUE t.renewalamountpaid,
                   'CURRENTGALLONAGE' VALUE t.currgallonage,
                   'ADDITIONALGALLONAGE' VALUE t.curraddionalgallonage,
                   'CREATEDDATE' VALUE t.createddate,
                   'GALLONAGE' VALUE t.gallonage261,
                   'AWFAMOUNTOWED' VALUE t.awffeeamount,
                   'AWFPAID' VALUE NULL
                   ABSENT ON NULL)
          INTO t_awf
          FROM bizmod_api.awf_t t
         --               LEFT OUTER JOIN bizmod_api.e_payments_t p ON p.feeobjid = t.renfeeobjid
         WHERE t.renfeeid = t_renfeeid;

        l_data.put('INFO',
                   TREAT(json_object_t.parse(t_awf) AS json_object_t));
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
